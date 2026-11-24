import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../board.dart';
import '../engine.dart';
import '../game_controller.dart';
import '../pgn.dart';
import 'play.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});
  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _game = GameController();
  EvalResult? _eval;
  bool _analyzing = false;
  int _depth = 12;

  @override
  void initState() {
    super.initState();
    Engine.instance.init();
  }

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    final ev = await Engine.instance.eval(_game.fen, depth: _depth);
    if (!mounted) return;
    setState(() {
      _eval = ev;
      _analyzing = false;
    });
  }

  Future<void> _exportPgn() async {
    final pgn = toPgn(
      _game.history,
      headers: {
        'Event': 'Opening Master analysis',
        'Date': DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '.'),
        'Result': _game.isOver ? _resultToken(_game.outcome) : '*',
      },
    );
    await Clipboard.setData(ClipboardData(text: pgn));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PGN copied to clipboard')));
  }

  Future<void> _importPgn() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import PGN'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Paste PGN here', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final sans = parsePgn(controller.text);
      if (sans.isEmpty) throw const FormatException('no moves found');
      _game.reset();
      for (final san in sans) {
        if (!_game.moveSan(san)) {
          throw FormatException('illegal move: $san (after ${_game.history.length} plies)');
        }
      }
      setState(() {});
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: ${e.message}')));
    }
  }

  String _resultToken(Outcome? outcome) => switch (outcome?.winner) {
        Side.white => '1-0',
        Side.black => '0-1',
        null => '1/2-1/2',
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ListView(children: [
        ChessBoard(
          position: _game.position,
          onMove: (m, san) => setState(() => _game.move(m, san)),
          lastMove: _game.lastMoveSquares,
        ),
        const SizedBox(height: 8),
        Row(children: [
          FilledButton.tonal(onPressed: () => setState(() => _game.undoTwo()), child: const Text('Undo')),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: () => setState(() => _game.reset()), child: const Text('Reset')),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: _exportPgn, child: const Text('Export PGN')),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: _importPgn, child: const Text('Import PGN')),
          const SizedBox(width: 8),
          FilledButton(onPressed: _analyzing ? null : _analyze, child: Text(_analyzing ? 'Analyzing…' : 'Analyze')),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _depth,
            items: [8, 12, 16, 20].map((d) => DropdownMenuItem(value: d, child: Text('d$d'))).toList(),
            onChanged: (v) => setState(() => _depth = v!),
          ),
        ]),
        if (_eval != null)
          Text('Eval: ${(_eval!.cp / 100).toStringAsFixed(2)} (White) · best: ${_eval!.bestMoveUci}'),
        const SizedBox(height: 8),
        MoveList(history: _game.history),
      ]),
    );
  }
}
