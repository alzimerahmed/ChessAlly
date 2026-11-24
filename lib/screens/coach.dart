import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../board.dart';
import '../data.dart';
import '../engine.dart';
import '../game_controller.dart';
import '../stats.dart';
import 'play.dart';

class CoachScreen extends StatefulWidget {
  final Stats stats;
  final void Function(Stats) setStats;
  const CoachScreen({super.key, required this.stats, required this.setStats});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _game = GameController();
  String _repId = 'london';
  EvalResult? _eval;
  String? _lastGrade;
  List<Square> _hint = [];

  Repertoire get rep => repById(_repId);
  Side get mySide => rep.side == 'white' ? Side.white : Side.black;
  bool get myTurn => _game.position.turn == mySide;

  @override
  void initState() {
    super.initState();
    Engine.instance.init().then((_) => _refreshCoach());
    _game.loadBook(repById(_repId)).then((_) { if (mounted) setState(() {}); _maybeAi(); });
    _maybeAi();
  }

  Future<void> _refreshCoach() async {
    if (_game.isOver || !myTurn) return;
    final ev = await Engine.instance.eval(_game.fen, depth: 12);
    if (!mounted) return;
    setState(() {
      _eval = ev;
      _hint = _uciSquares(ev.bestMoveUci);
    });
  }

  Future<void> _maybeAi() async {
    if (_game.isOver || myTurn) return;
    // coach games use the book bot so play stays inside your repertoire
    await _game.aiMoveBook(rep, profile: BotProfile.club);
    if (!mounted) return;
    setState(() => _hint = []);
    _refreshCoach();
  }

  void _onMove(Move m, String san) {
    // masters dataset first, then the curated tree
    final isBook = _game.isBookMove(san) ||
        bookReplies(rep, _game.history).map((c) => c.move!).contains(san);
    setState(() {
      _game.move(m, san);
      _lastGrade = isBook ? '✅ Book move' : '⚠️ Off book. Engine prefers ${_evalBestSan() ?? 'a non-book line'}';
      _hint = [];
    });
    _maybeAi();
  }

  String? _evalBestSan() {
    if (_eval == null) return null;
    final m = _parseUciMove(_eval!.bestMoveUci);
    if (m == null) return _eval!.bestMoveUci;
    // eval may be stale after further moves — only show legal suggestions
    if (!_game.position.isLegal(m)) return null;
    return _game.position.makeSan(m).$2;
  }

  Move? _parseUciMove(String uci) {
    if (uci.length < 4) return null;
    final from = Square.fromName(uci.substring(0, 2));
    final to = Square.fromName(uci.substring(2, 4));
    Role? promo;
    if (uci.length > 4) {
      promo = switch (uci[4]) {
        'q' => Role.queen,
        'r' => Role.rook,
        'b' => Role.bishop,
        'n' => Role.knight,
        _ => null,
      };
    }
    return NormalMove(from: from, to: to, promotion: promo);
  }

  List<Square> _uciSquares(String uci) {
    if (uci.length < 4) return [];
    return [Square.fromName(uci.substring(0, 2)), Square.fromName(uci.substring(2, 4))];
  }

  @override
  Widget build(BuildContext context) {
    final bookMoves = bookReplies(rep, _game.history).map((c) => c.move!).join(', ');
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ListView(children: [
        DropdownButton<String>(
          value: _repId,
          isExpanded: true,
          items: repertoires.map((r) => DropdownMenuItem(value: r.id, child: Text('${r.name} (${r.side})'))).toList(),
          onChanged: (v) {
            setState(() => _repId = v!);
            _game.loadBook(repById(_repId)).then((_) => mounted ? setState(() {}) : null);
          },
        ),
        const SizedBox(height: 4),
        ChessBoard(
          position: _game.position,
          whiteOnBottom: mySide == Side.white,
          onMove: myTurn && !_game.isOver ? _onMove : null,
          highlight: _hint,
          lastMove: _game.lastMoveSquares,
        ),
        const SizedBox(height: 8),
        Row(children: [
          FilledButton.tonal(onPressed: () => setState(() => _game.undoTwo()), child: const Text('Undo')),
          const SizedBox(width: 8),
          FilledButton(onPressed: () { _game.reset(); setState(() {}); _maybeAi(); }, child: const Text('New game')),
          if (_game.thinking) const Padding(padding: EdgeInsets.only(left: 8), child: Text('thinking…')),
        ]),
        if (_lastGrade != null) Text(_lastGrade!, style: const TextStyle(fontSize: 16)),
        if (_eval != null)
          Text('Eval ${( _eval!.cp / 100).toStringAsFixed(2)} (White) · best: ${_eval!.bestMoveUci}'),
        const SizedBox(height: 8),
        Text('Book moves here: ${bookMoves.isEmpty ? '—' : bookMoves}'),
        const SizedBox(height: 8),
        MoveList(history: _game.history),
      ]),
    );
  }
}
