import 'dart:math';
import 'package:dartchess/dartchess.dart';
import 'book.dart';
import 'data.dart';
import 'engine.dart';

/// Bot difficulty: engine depth + how it picks book (repertoire) replies.
enum BotProfile {
  beginner('Beginner', 2), // always the most popular reply
  casual('Casual', 6), // frequency-weighted
  club('Club', 10), // frequency-weighted, deeper engine
  sharp('Sharp', 12), // rare book moves — tests edge cases
  master('Master', 14); // statistically strongest book moves

  final String label;
  final int depth;
  const BotProfile(this.label, this.depth);
}

/// Shared game state: position, SAN history, undo stack, AI replies.
class GameController {
  final Random _rng = Random();
  MasterBook? _masterBook;

  /// Preload the masters dataset for a repertoire (call when repertoire changes).
  Future<void> loadBook(Repertoire rep) async {
    try {
      _masterBook = await MasterBook.load(rep.id, trunk: rep.trunk);
    } catch (_) {
      _masterBook = null; // dataset unavailable — fall back to built-in tree
    }
  }
  Position position = Chess.initial;
  final List<String> history = []; // SAN
  final List<Position> _stack = [Chess.initial];
  bool thinking = false;

  String get fen => position.fen;
  bool get isOver => position.isGameOver;
  Outcome? get outcome => position.outcome;

  List<Square> get lastMoveSquares => _lastMove;

  List<Square> _lastMove = [];

  bool move(Move m, String san) {
    final next = position.makeSan(m);
    position = next.$1;
    history.add(next.$2);
    _stack.add(position);
    if (m is NormalMove) _lastMove = [m.from, m.to];
    return true;
  }

  /// Play a SAN move by parsing it.
  bool moveSan(String san) {
    final m = position.parseSan(san);
    if (m == null) return false;
    return move(m, san);
  }

  void undoTwo() {
    if (_stack.length > 1) _stack.removeLast();
    if (_stack.length > 1) _stack.removeLast();
    position = _stack.last;
    while (history.length >= _stack.length) {
      history.removeLast();
    }
    _lastMove = [];
  }

  void reset() {
    position = Chess.initial;
    history.clear();
    _stack
      ..clear()
      ..add(position);
    _lastMove = [];
    thinking = false;
  }

  /// Book bot: play from the masters dataset while on-book (selection depends
  /// on [profile]); fall back to the built-in curated tree, then to the engine.
  /// Returns ({san, source}) or null.
  Future<({String san, String source})?> aiMoveBook(Repertoire rep, {BotProfile profile = BotProfile.club}) async {
    if (position.isGameOver) return null;

    // 1) masters dataset
    if (_masterBook != null) {
      final BookMove? pick = switch (profile) {
        BotProfile.beginner => _masterBook!.mainline(history),
        BotProfile.casual || BotProfile.club => _masterBook!.pickWeighted(history),
        BotProfile.sharp => _masterBook!.pickRare(history),
        BotProfile.master => _masterBook!.best(history, minGames: 200) ?? _masterBook!.pickWeighted(history),
      };
      if (pick != null) {
        final m = _parseUci(pick.uci);
        if (m != null) {
          final (next, san) = position.makeSan(m);
          position = next;
          history.add(san);
          _stack.add(position);
          if (m is NormalMove) _lastMove = [m.from, m.to];
          return (san: san, source: 'book');
        }
      }
    }

    // 2) built-in curated tree
    final replies = bookReplies(rep, history);
    if (replies.isNotEmpty) {
      final pool = <TreeNode>[];
      for (final r in replies) {
        pool.add(r);
        pool.add(r);
        if (r.key) pool.add(r);
      }
      final pick = pool[_rng.nextInt(pool.length)];
      final m = position.parseSan(pick.move!);
      if (m != null) {
        move(m, pick.move!);
        return (san: pick.move!, source: 'book');
      }
    }

    // 3) engine fallback
    thinking = true;
    EvalResult ev;
    try {
      ev = await Engine.instance.eval(position.fen, depth: profile.depth);
    } catch (_) {
      thinking = false;
      return null; // engine unavailable
    }
    thinking = false;
    if (ev.bestMoveUci.isEmpty || position.isGameOver) return null;
    final m = _parseUci(ev.bestMoveUci);
    if (m == null) return null;
    final (next, san) = position.makeSan(m);
    position = next;
    history.add(san);
    _stack.add(position);
    if (m is NormalMove) _lastMove = [m.from, m.to];
    return (san: san, source: 'engine');
  }

  /// Engine picks a move at [depth] and plays it. Returns SAN played or null.
  Future<String?> aiMove({int depth = 10}) async {
    if (position.isGameOver) return null;
    thinking = true;
    final ev = await Engine.instance.eval(position.fen, depth: depth);
    thinking = false;
    if (ev.bestMoveUci.isEmpty || position.isGameOver) return null;
    final m = _parseUci(ev.bestMoveUci);
    if (m == null) return null;
    final (next, san) = position.makeSan(m);
    position = next;
    history.add(san);
    _stack.add(position);
    if (m is NormalMove) _lastMove = [m.from, m.to];
    return san;
  }

  /// Is [san] a masters-dataset book move at the current path?
  bool isBookMove(String san) =>
      _masterBook != null && _masterBook!.movesAt(history).any((b) => b.san == san);

  Move? _parseUci(String uci) {    if (uci.length < 4) return null;
    final from = Square.fromName(uci.substring(0, 2));
    final to = Square.fromName(uci.substring(2, 4));
    final promo = uci.length > 4 ? _promoRole(uci[4]) : null;
    return NormalMove(from: from, to: to, promotion: promo);
  }

  Role? _promoRole(String c) => switch (c) {
        'q' => Role.queen,
        'r' => Role.rook,
        'b' => Role.bishop,
        'n' => Role.knight,
        _ => null,
      };
}
