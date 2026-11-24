import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

final Random _rng = Random();

/// A move entry from the Lichess masters explorer dataset.
class BookMove {
  final String san, uci;
  final int games, white, draws, black, avg;
  final List<BookMove> children;
  BookMove({
    required this.san,
    required this.uci,
    required this.games,
    required this.white,
    required this.draws,
    required this.black,
    required this.avg,
    this.children = const [],
  });

  factory BookMove.fromJson(dynamic j) => BookMove(
        san: j['san'],
        uci: j['uci'],
        games: j['games'],
        white: j['white'],
        draws: j['draws'],
        black: j['black'],
        avg: j['avg'],
        children: (j['children'] as List? ?? []).map(BookMove.fromJson).toList(),
      );

  double get score => white + draws / 2.0;
}

/// The masters-dataset book for one repertoire. The dataset root is the
/// position after the repertoire trunk, so paths are trunk-relative.
class MasterBook {
  final String repId;
  final List<String> trunk;
  final List<BookMove> root;
  MasterBook(this.repId, this.trunk, this.root);

  static final Map<String, MasterBook> _cache = {};

  static Future<MasterBook> load(String repId, {List<String> trunk = const []}) async {
    final cached = _cache[repId];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/book/$repId.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final book = MasterBook(repId, trunk, (data['moves'] as List).map(BookMove.fromJson).toList());
    _cache[repId] = book;
    return book;
  }

  /// Book moves available at a full SAN path from the start (empty = off-book).
  List<BookMove> movesAt(List<String> path) {
    if (path.length < trunk.length) return const [];
    for (var i = 0; i < trunk.length; i++) {
      if (trunk[i] != path[i]) return const [];
    }
    List<BookMove> level = root;
    for (final san in path.sublist(trunk.length)) {
      BookMove? next;
      for (final m in level) {
        if (m.san == san) {
          next = m;
          break;
        }
      }
      if (next == null) return const [];
      level = next.children;
    }
    return level;
  }

  /// Frequency-weighted random pick among book moves.
  BookMove? pickWeighted(List<String> path, {double keyBias = 1.0}) {
    final moves = movesAt(path);
    if (moves.isEmpty) return null;
    final total = moves.fold<double>(0, (s, m) => s + m.games);
    var r = _rng.nextDouble() * total;
    for (final m in moves) {
      r -= m.games;
      if (r <= 0) return m;
    }
    return moves.last;
  }

  /// Pick weighted toward RARE moves (inverse frequency) — tests edge cases.
  BookMove? pickRare(List<String> path) {
    final moves = movesAt(path);
    if (moves.isEmpty) return null;
    if (moves.length == 1) return moves.first;
    final total = moves.fold<double>(0, (s, m) => s + 1.0 / m.games);
    var r = _rng.nextDouble() * total;
    for (final m in moves) {
      r -= 1.0 / m.games;
      if (r <= 0) return m;
    }
    return moves.first;
  }

  /// The statistically strongest reply for the side to move at this node
  /// (by win+draw share, requiring a minimum sample).
  BookMove? best(List<String> path, {int minGames = 500}) {
    final moves = movesAt(path).where((m) => m.games >= minGames).toList();
    if (moves.isEmpty) return null;
    final moverIsWhite = path.length.isEven; // side to move at this node
    double score(BookMove m) => moverIsWhite ? m.white + m.draws / 2.0 : m.black + m.draws / 2.0;
    moves.sort((a, b) => score(b).compareTo(score(a)));
    return moves.first;
  }

  /// Most-played reply (the mainline the user must know).
  BookMove? mainline(List<String> path) {
    final moves = movesAt(path);
    if (moves.isEmpty) return null;
    return moves.reduce((a, b) => a.games > b.games ? a : b);
  }
}
