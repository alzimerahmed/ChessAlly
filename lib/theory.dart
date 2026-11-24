import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// One continuation listed in a node's top-3.
class TopMove {
  final String san;
  final int games, white, draws, black;
  const TopMove({required this.san, required this.games, required this.white, required this.draws, required this.black});

  factory TopMove.fromJson(dynamic j) => TopMove(
        san: j['san'],
        games: j['games'],
        white: j['white'],
        draws: j['draws'],
        black: j['black'],
      );

  double get winPct => games == 0 ? 0 : (white + draws / 2.0) / games * 100;
}

/// A position in the theory tree with club-data statistics.
class TheoryNode {
  final List<String> path; // full SAN path from the game start
  final String fen;
  final int games, white, draws, black;
  final String? name, comment;
  final List<TopMove> top;
  const TheoryNode({
    required this.path,
    required this.fen,
    required this.games,
    required this.white,
    required this.draws,
    required this.black,
    required this.top,
    this.name,
    this.comment,
  });

  factory TheoryNode.fromJson(dynamic j) => TheoryNode(
        path: List<String>.from(j['path']),
        fen: j['fen'],
        games: j['games'],
        white: j['white'],
        draws: j['draws'],
        black: j['black'],
        name: j['name'],
        comment: j['comment'],
        top: (j['top'] as List? ?? []).map(TopMove.fromJson).toList(),
      );

  String get key => path.join(' ');
  double get winPct => games == 0 ? 0 : (white + draws / 2.0) / games * 100;
  double get drawPct => games == 0 ? 0 : draws / games * 100;
  double get lossPct => games == 0 ? 0 : black / games * 100;

  /// Side to move at this node.
  bool get whiteToMove => path.length.isEven;
}

/// The full theory tree for one repertoire (`assets/theory/<rep>.json`).
/// Node paths are full SAN paths from the game start; the dataset root is
/// the position after the trunk, so the top-level nodes sit at [trunk].
class TheorySet {
  final String repId;
  final List<String> trunk;
  final List<TheoryNode> nodes;
  final Map<String, List<TheoryNode>> _byParent;
  TheorySet(this.repId, this.trunk, this.nodes)
      : _byParent = _index(nodes);

  /// Root path of the tree browser (the repertoire trunk).
  List<String> get rootPath => trunk;

  static Map<String, List<TheoryNode>> _index(List<TheoryNode> nodes) {
    final idx = <String, List<TheoryNode>>{};
    for (final n in nodes) {
      final parent = n.path.sublist(0, n.path.length - 1).join(' ');
      idx.putIfAbsent(parent, () => []).add(n);
    }
    return idx;
  }

  static final Map<String, TheorySet> _cache = {};

  static Future<TheorySet> load(String repId) async {
    final cached = _cache[repId];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/theory/$repId.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final set = TheorySet(
      repId,
      List<String>.from(data['trunk'] ?? const []),
      (data['nodes'] as List).map(TheoryNode.fromJson).toList(),
    );
    _cache[repId] = set;
    return set;
  }

  /// Child nodes (one move deeper) at a path; empty path = game start.
  List<TheoryNode> childrenOf(List<String> path) => _byParent[path.join(' ')] ?? const [];

  /// Nodes where the given side ('white'/'black') is to move and has book moves.
  List<TheoryNode> quizNodes(String side) => nodes
      .where((n) => n.top.isNotEmpty && (side == 'white') == n.whiteToMove)
      .toList();
}
