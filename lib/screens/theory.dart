import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../board.dart';
import '../data.dart';
import '../stats.dart';
import '../theory.dart';
import 'play.dart';

class TheoryScreen extends StatefulWidget {
  final Stats stats;
  final void Function(Stats) setStats;
  const TheoryScreen({super.key, required this.stats, required this.setStats});
  @override
  State<TheoryScreen> createState() => _TheoryScreenState();
}

class _TheoryScreenState extends State<TheoryScreen> {
  String _mode = 'lines'; // 'lines' | 'tree' | 'quiz'
  String _repId = 'london';

  // lines walkthrough (existing mode)
  int _lineIdx = 0;
  int _ply = 0;

  // tree browser
  TheorySet? _theory;
  final Set<String> _expanded = {};
  String? _selected; // node key

  // quiz
  TheoryNode? _quizNode;
  String? _quizFeedback;
  bool _quizDone = false;
  List<String> _quizTried = [];

  Repertoire get rep => repById(_repId);
  OpeningLine get line => rep.lines[_lineIdx];

  @override
  void initState() {
    super.initState();
    _loadTheory();
  }

  Future<void> _loadTheory() async {
    TheorySet? t;
    try {
      t = await TheorySet.load(_repId);
    } catch (_) {
      t = null; // dataset not generated yet
    }
    if (!mounted) return;
    setState(() {
      _theory = t;
      _expanded.clear();
      _selected = null;
      _quizNode = null;
    });
  }

  void _complete() {
    final s = widget.stats;
    s.linesSeen[line.id] = (s.linesSeen[line.id] ?? 0) + 1;
    s.lineMastery[line.id] = ((s.lineMastery[line.id] ?? 0) + 10).clamp(0, 100);
    s.touchDaily();
    saveStats(s);
    widget.setStats(s);
  }

  // ===== tree browser =====

  TheoryNode? get _selectedNode {
    if (_theory == null || _selected == null) return null;
    for (final n in _theory!.nodes) {
      if (n.key == _selected) return n;
    }
    return null;
  }

  List<Widget> _treeRows() {
    final theory = _theory!;
    final rows = <Widget>[];
    void addChildren(List<String> path, int depth) {
      for (final n in _theory!.childrenOf(path)) {
        final hasKids = _theory!.childrenOf(n.path).isNotEmpty;
        final isExpanded = _expanded.contains(n.key);
        final isSelected = _selected == n.key;
        rows.add(InkWell(
          onTap: () => setState(() => _selected = n.key),
          child: Container(
            color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
            padding: EdgeInsets.only(left: 8.0 + depth * 20, top: 4, bottom: 4),
            child: Row(children: [
              if (hasKids)
                InkWell(
                  onTap: () => setState(() {
                    if (isExpanded) {
                      _expanded.remove(n.key);
                    } else {
                      _expanded.add(n.key);
                    }
                  }),
                  child: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 18),
                )
              else
                const SizedBox(width: 18),
              const SizedBox(width: 4),
              Text(n.path.last, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Text('${n.games} games · ${n.winPct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ]),
          ),
        ));
        if (isExpanded && hasKids) addChildren(n.path, depth + 1);
      }
    }

    addChildren(theory.rootPath, 0);
    return rows;
  }

  // ===== quiz =====

  void _newQuiz() {
    final quizables = _theory?.quizNodes(rep.side) ?? const [];
    if (quizables.isEmpty) return;
    quizables.shuffle();
    setState(() {
      _quizNode = quizables.first;
      _quizFeedback = null;
      _quizDone = false;
      _quizTried = [];
    });
  }

  Position get _quizPos {
    Position p = Chess.initial;
    for (final san in _quizNode?.path ?? const <String>[]) {
      final m = p.parseSan(san);
      if (m != null) p = p.playUnchecked(m);
    }
    return p;
  }

  void _onQuizMove(Move m, String san) {
    final node = _quizNode;
    if (node == null || _quizDone) return;
    final bookSans = node.top.map((t) => t.san).toSet();
    // any dataset continuation at this node is theory-conformant
    final allChildren = _theory!.childrenOf(node.path).map((n) => n.path.last).toSet();
    if (bookSans.contains(san) || allChildren.contains(san)) {
      final mainline = node.top.isEmpty ? san : node.top.first.san;
      setState(() {
        _quizDone = true;
        _quizFeedback = san == mainline ? '✅ Mainline! ($san)' : '✅ Book move. Mainline: $mainline';
      });
    } else {
      setState(() {
        _quizFeedback = '❌ Off theory — try again.';
        _quizTried = [..._quizTried, san];
      });
    }
  }

  // ===== build =====

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ListView(children: [
        Row(children: [
          Expanded(
            child: DropdownButton<String>(
              value: _repId,
              isExpanded: true,
              items: repertoires.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
              onChanged: (v) {
                setState(() {
                  _repId = v!;
                  _lineIdx = 0;
                  _ply = 0;
                });
                _loadTheory();
              },
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'lines', label: Text('Lines')),
              ButtonSegment(value: 'tree', label: Text('Tree')),
              ButtonSegment(value: 'quiz', label: Text('Quiz')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ]),
        const SizedBox(height: 8),
        if (_mode == 'lines') _buildLines() else if (_mode == 'tree') _buildTree() else _buildQuiz(),
      ]),
    );
  }

  Widget _buildLines() {
    if (_ply == 0) _ply = line.moves.length;
    final done = _ply >= line.moves.length;
    final comment = line.comments[_ply - 1];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButton<int>(
        value: _lineIdx,
        isExpanded: true,
        items: [for (var i = 0; i < rep.lines.length; i++) DropdownMenuItem(value: i, child: Text(rep.lines[i].name, overflow: TextOverflow.ellipsis))],
        onChanged: (v) => setState(() { _lineIdx = v!; _ply = 0; }),
      ),
      Text(line.idea, style: const TextStyle(fontStyle: FontStyle.italic)),
      const SizedBox(height: 4),
      ChessBoard(position: _linesPos, whiteOnBottom: rep.side == 'white', interactive: false),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        FilledButton.tonal(onPressed: () => setState(() => _ply = (_ply - 1).clamp(0, line.moves.length)), child: const Text('◀ Back')),
        FilledButton.tonal(onPressed: () => setState(() => _ply = (_ply + 1).clamp(0, line.moves.length)), child: const Text('Next ▶')),
        FilledButton.tonal(onPressed: () => setState(() => _ply = line.moves.length), child: const Text('End')),
      ]),
      if (done && (widget.stats.linesSeen[line.id] ?? 0) == 0)
        TextButton(onPressed: _complete, child: const Text('Mark line studied (+10% mastery)')),
      if (comment != null)
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(8),
          color: const Color(0xFFF4F0E0),
          child: Text('💬 $comment'),
        ),
      Text('Mastery: ${widget.stats.lineMastery[line.id] ?? 0}% · studied ${widget.stats.linesSeen[line.id] ?? 0}×'),
      const SizedBox(height: 8),
      MoveList(history: line.moves.sublist(0, _ply)),
    ]);
  }

  Position get _linesPos {
    Position p = Chess.initial;
    for (var i = 0; i < _ply && i < line.moves.length; i++) {
      final m = p.parseSan(line.moves[i]);
      if (m != null) p = p.playUnchecked(m);
    }
    return p;
  }

  Widget _buildTree() {
    final theory = _theory;
    if (theory == null) {
      return const Text('Theory dataset not built yet. Run: dart run tools/build_theory.dart');
    }
    final sel = _selectedNode;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ChessBoard(
        position: _posAtPath(sel?.path ?? theory.rootPath),
        whiteOnBottom: rep.side == 'white',
        interactive: false,
      ),
      const SizedBox(height: 8),
      if (sel != null) ...[
        Text(
          '${sel.path.join(' ')}  (${sel.games} games)',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        if (sel.name != null) Text(sel.name!, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'W ${sel.winPct.toStringAsFixed(1)}% · D ${sel.drawPct.toStringAsFixed(1)}% · L ${sel.lossPct.toStringAsFixed(1)}%',
        ),
        if (sel.comment != null)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(8),
            color: const Color(0xFFF4F0E0),
            child: Text('💬 ${sel.comment}'),
          ),
        if (sel.top.isNotEmpty) ...[
          const Text('Top continuations', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
          Wrap(
            spacing: 8,
            children: [
              for (final t in sel.top)
                ActionChip(
                  label: Text('${t.san} ${t.winPct.toStringAsFixed(0)}% (${t.games})'),
                  onPressed: () => setState(() {
                    _selected = [...sel.path, t.san].join(' ');
                    _expanded.add(sel.key);
                  }),
                ),
            ],
          ),
        ],
        const Divider(),
      ],
      Text('Variation tree (${theory.nodes.length} positions)', style: Theme.of(context).textTheme.titleSmall),
      ..._treeRows(),
    ]);
  }

  Position _posAtPath(List<String> path) {
    Position p = Chess.initial;
    for (final san in path) {
      final m = p.parseSan(san);
      if (m != null) p = p.playUnchecked(m);
    }
    return p;
  }

  Widget _buildQuiz() {
    final theory = _theory;
    if (theory == null) {
      return const Text('Theory dataset not built yet. Run: dart run tools/build_theory.dart');
    }
    final node = _quizNode;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        FilledButton(onPressed: _newQuiz, child: const Text('Quiz me on this opening')),
        if (node != null)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('${node.games} games at this position', overflow: TextOverflow.ellipsis),
            ),
          ),
      ]),
      if (node != null) ...[
        const SizedBox(height: 8),
        Text('Find a book move for ${rep.side} (${node.path.length} plies in):'),
        ChessBoard(
          position: _quizPos,
          whiteOnBottom: rep.side == 'white',
          onMove: _quizDone ? null : _onQuizMove,
        ),
        if (_quizFeedback != null) Text(_quizFeedback!, style: const TextStyle(fontSize: 18)),
        if (_quizTried.isNotEmpty) Text('Tried: ${_quizTried.join(', ')}'),
        TextButton(onPressed: _newQuiz, child: const Text('Next question')),
      ] else
        const Text('Press "Quiz me" to start.'),
    ]);
  }
}
