import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../board.dart';
import '../book.dart';
import '../data.dart';
import '../review.dart';

const _tagLabels = {
  MoveTag.book: 'Book',
  MoveTag.best: 'Best',
  MoveTag.excellent: 'Excellent',
  MoveTag.good: 'Good',
  MoveTag.inaccuracy: 'Inacc.',
  MoveTag.mistake: 'Mistake',
  MoveTag.blunder: 'Blunder',
};

const _tagColors = {
  MoveTag.book: Colors.blue,
  MoveTag.best: Colors.green,
  MoveTag.excellent: Colors.lightGreen,
  MoveTag.good: Colors.teal,
  MoveTag.inaccuracy: Colors.amber,
  MoveTag.mistake: Colors.orange,
  MoveTag.blunder: Colors.red,
};

/// Post-game review: evaluates every move, shows accuracy, tagged move list,
/// key moments, and lets you jump to any position.
class ReviewScreen extends StatefulWidget {
  final List<String> history; // SAN
  final String repId;
  final Side mySide;
  final void Function(({double overall, double? bookAcc, double? offBookAcc, String? lineId}))? onAccuracy;
  const ReviewScreen({super.key, required this.history, required this.repId, required this.mySide, this.onAccuracy});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  GameReview? _review;
  bool _running = false;
  int _done = 0, _total = 0;
  int _ply = 0; // position index currently shown (0 = start)
  List<Position> _positions = const [];
  List<List<Square>> _lastMoves = const [];
  MasterBook? _book;

  @override
  void initState() {
    super.initState();
    _replay();
    MasterBook.load(widget.repId, trunk: repById(widget.repId).trunk).then((b) {
      _book = b;
      if (mounted && !_running) _start();
    }).catchError((_) {
      if (mounted && !_running) _start();
    });
  }

  void _replay() {
    final positions = <Position>[Chess.initial];
    final lastMoves = <List<Square>>[const []];
    Position pos = Chess.initial;
    for (final san in widget.history) {
      final m = pos.parseSan(san);
      if (m == null) break;
      pos = pos.makeSan(m).$1;
      positions.add(pos);
      lastMoves.add(m is NormalMove ? [(m).from, (m).to] : const []);
    }
    _positions = positions;
    _lastMoves = lastMoves;
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _total = 0; // actual total comes from the first progress callback
      _done = 0;
    });
    final review = await analyzeGame(
      widget.history,
      book: _book,
      onProgress: (d, t) => mounted ? setState(() { _done = d; _total = t; }) : null,
    );
    if (!mounted) return;
    setState(() {
      _review = review;
      _running = false;
    });
    // per-game summary for stats: overall / on-book / off-book accuracy, line id
    final myMoves = review.moves.where((m) => m.side == widget.mySide).toList();
    double? avg(List<ReviewedMove> l) =>
        l.isEmpty ? null : l.fold<double>(0, (a, m) => a + m.accuracy) / l.length;
    String? lineId;
    try {
      lineId = matchLineId(repById(widget.repId), widget.history);
    } catch (_) {}
    widget.onAccuracy?.call((
      overall: review.myAccuracy(widget.mySide),
      bookAcc: avg(myMoves.where((m) => m.tag == MoveTag.book).toList()),
      offBookAcc: avg(myMoves.where((m) => m.tag != MoveTag.book).toList()),
      lineId: lineId,
    ));
  }

  void _jump(int ply) => setState(() => _ply = ply.clamp(0, _positions.length - 1));

  @override
  Widget build(BuildContext context) {
    final review = _review;
    return Scaffold(
      appBar: AppBar(title: const Text('Game review')),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: ListView(children: [
          if (_running) ...[
            Text(_total > 0 ? 'Analyzing $_done/$_total…' : 'Analyzing…'),
            LinearProgressIndicator(value: _total > 0 ? _done / _total : null),
            const SizedBox(height: 8),
          ],
          ChessBoard(
            position: _positions[_ply],
            lastMove: _lastMoves[_ply],
            interactive: false,
          ),
          const SizedBox(height: 4),
          Text('Move ${_ply == 0 ? '— start' : '${(_ply + 1) / 2}... ${widget.history[_ply - 1]}'}',
              textAlign: TextAlign.center),
          if (review != null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _accChip('White', review.whiteAccuracy, Side.white),
              _accChip('Black', review.blackAccuracy, Side.black),
            ]),
            const SizedBox(height: 8),
            if (review.keyMoments().isNotEmpty) ...[
              Text('Key moments', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in review.keyMoments())
                    ActionChip(
                      label: Text(
                        '${m.side == Side.white ? 'W' : 'B'} ${m.san} (−${m.cpLoss})',
                        style: TextStyle(color: _tagColors[m.tag]),
                      ),
                      onPressed: () => _jump(m.ply + 1),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Text('Moves', style: Theme.of(context).textTheme.titleSmall),
            _moveTable(review),
          ],
        ]),
      ),
    );
  }

  Widget _accChip(String label, double acc, Side side) {
    final played = _review!.moves.any((m) => m.side == side);
    return Chip(label: Text('$label ${played ? '${acc.toStringAsFixed(1)}%' : '—'}'));
  }

  Widget _moveTable(GameReview review) {
    final rows = <TableRow>[
      TableRow(children: [Text('#'), Text('White'), Text('Black')].map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: w)).toList()),
    ];
    final byPly = {for (final m in review.moves) m.ply: m};
    for (var i = 0; i < widget.history.length; i += 2) {
      Widget cell(int ply) {
        final m = byPly[ply];
        if (m == null) return const Text('');
        return InkWell(
          onTap: () => _jump(ply + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: m.san, style: TextStyle(color: _tagColors[m.tag], fontWeight: FontWeight.bold)),
                TextSpan(text: ' ${_tagLabels[m.tag]}', style: const TextStyle(fontSize: 11)),
                if (m.isMiss) const TextSpan(text: ' (miss)', style: TextStyle(fontSize: 11, color: Colors.purple)),
              ]),
            ),
          ),
        );
      }

      rows.add(TableRow(children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('${i ~/ 2 + 1}.')),
        cell(i),
        cell(i + 1),
      ]));
    }
    return Table(columnWidths: const {0: FixedColumnWidth(36)}, border: TableBorder(horizontalInside: BorderSide(color: Colors.grey.shade300)), children: rows);
  }
}
