import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../board.dart';
import '../data.dart';
import '../puzzles.dart';
import '../stats.dart';
import 'play.dart';

class PuzzlesScreen extends StatefulWidget {
  final Stats stats;
  final void Function(Stats) setStats;
  const PuzzlesScreen({super.key, required this.stats, required this.setStats});
  @override
  State<PuzzlesScreen> createState() => _PuzzlesScreenState();
}

class _PuzzlesScreenState extends State<PuzzlesScreen> {
  String _mode = 'drills'; // 'drills' | 'tactics'

  // --- book drills state (existing mode) ---
  String _repId = 'london';
  int _lineIdx = 0;
  int _pz = 0;
  String? _feedback;
  List<String> _wrong = [];

  // --- tactics state (Lichess DB puzzles) ---
  PuzzleSet? _set;
  String? _theme; // null = all themes
  Puzzle? _puzzle;
  Position? _pos;
  int _solutionIdx = 0;
  final List<String> _sans = [];
  bool _failedThisPuzzle = false;
  bool _replyPending = false; // opponent reply is being auto-played
  bool _done = false; // solved or solution shown — board locked
  bool _daily = false;

  Repertoire get rep => repById(_repId);
  OpeningLine get line => rep.lines[_lineIdx];
  List<({List<String> path, String answer})> get puzzles => puzzlePositions(line, rep.side);
  ({List<String> path, String answer}) get puzzle => puzzles[_pz];

  @override
  void initState() {
    super.initState();
    _loadSet();
  }

  Future<void> _loadSet() async {
    PuzzleSet? set;
    try {
      set = await PuzzleSet.load(_repId);
    } catch (_) {
      set = null; // dataset not generated yet
    }
    if (!mounted) return;
    setState(() => _set = set);
    if (_mode == 'tactics') _nextTactics();
  }

  void _record(bool correct) {
    final s = widget.stats;
    s.puzzlesAttempted++;
    s.recordPuzzleResult(_repId, correct);
    if (correct) {
      s.puzzlesCorrect++;
      s.puzzleStreak++;
      if (s.puzzleStreak > s.puzzleBestStreak) s.puzzleBestStreak = s.puzzleStreak;
    } else {
      s.puzzleStreak = 0;
    }
    s.touchDaily();
    s.touchWeekly();
    s.weekPuzzles++;
    saveStats(s);
    widget.setStats(s);
  }

  void _next() {
    setState(() {
      _feedback = null;
      _wrong = [];
      _pz = (_pz + 1) % puzzles.length;
    });
  }

  // ===== tactics mode =====

  List<Puzzle> get _filtered {
    final all = _set?.puzzles ?? const [];
    if (_theme == null) return all;
    return all.where((p) => p.themes.contains(_theme)).toList();
  }

  void _loadTactics(Puzzle p, {bool daily = false}) {
    setState(() {
      _puzzle = p;
      _pos = Chess.fromSetup(Setup.parseFen(p.fen));
      _solutionIdx = 0;
      _sans.clear();
      _feedback = null;
      _failedThisPuzzle = false;
      _replyPending = false;
      _done = false;
      _daily = daily;
      // Lichess convention: solutionMoves[0] is the opponent's move —
      // auto-play it so the solver faces the position to solve.
      if (p.solutionMoves.length > 1) {
        _applyUci(p.solutionMoves[0]);
        _solutionIdx = 1;
      }
    });
  }

  void _nextTactics() {
    final list = _filtered;
    if (list.isEmpty) {
      setState(() {
        _puzzle = null;
        _feedback = null;
      });
      return;
    }
    final current = _puzzle;
    var idx = current == null ? 0 : list.indexWhere((p) => p.id == current.id) + 1;
    if (idx >= list.length || idx < 1) idx = 0;
    _loadTactics(list[idx]);
  }

  void _recordTactics(bool solved) {
    _record(solved);
    final s = widget.stats;
    final p = _puzzle;
    if (p != null) {
      s.puzzleRating = updatePuzzleRating(s.puzzleRating, p.rating, solved);
      final key = '$_repId|${p.id}';
      if (solved) {
        s.puzzleRetryQueue.remove(key);
      } else if (!s.puzzleRetryQueue.contains(key)) {
        s.puzzleRetryQueue.add(key);
      }
      saveStats(s);
      widget.setStats(s);
    }
  }

  void _applyUci(String uci) {
    final m = NormalMove.fromUci(uci);
    final (next, san) = _pos!.makeSan(m);
    _pos = next;
    _sans.add(san);
  }

  void _onTacticsMove(Move m, String san) {
    final p = _puzzle;
    if (p == null || _pos == null || _done || _replyPending) return;
    final uci = _uciOf(m);
    if (uci == p.solutionMoves[_solutionIdx]) {
      _applyUci(uci);
      _solutionIdx++;
      if (_solutionIdx >= p.solutionMoves.length) {
        _recordTactics(true);
        setState(() {
          _done = true;
          _feedback = '✅ Solved! (+rating)';
        });
        Future.delayed(const Duration(milliseconds: 900), _nextTactics);
      } else {
        setState(() => _replyPending = true);
        // play the opponent reply after a beat; it may be the final move
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted || _puzzle?.id != p.id) return;
          var solvedNow = false;
          setState(() {
            _applyUci(p.solutionMoves[_solutionIdx]);
            _solutionIdx++;
            _replyPending = false;
            if (_solutionIdx >= p.solutionMoves.length) {
              solvedNow = true;
              _done = true;
              _feedback = '✅ Solved! (+rating)';
            }
          });
          if (solvedNow) {
            _recordTactics(true);
            Future.delayed(const Duration(milliseconds: 900), _nextTactics);
          }
        });
      }
    } else {
      if (!_failedThisPuzzle) {
        _failedThisPuzzle = true;
        _recordTactics(false);
      }
      setState(() => _feedback = '❌ Not the solution — try again.');
    }
  }

  void _showSolution() {
    final p = _puzzle;
    if (p == null || _pos == null) return;
    if (!_failedThisPuzzle) {
      _failedThisPuzzle = true;
      _recordTactics(false);
    }
    setState(() {
      while (_solutionIdx < p.solutionMoves.length) {
        _applyUci(p.solutionMoves[_solutionIdx]);
        _solutionIdx++;
      }
      _done = true;
      _feedback = 'Solution shown.';
    });
  }

  void _retryQueued() {
    final queue = widget.stats.puzzleRetryQueue.where((k) => k.startsWith('$_repId|')).toList();
    if (queue.isEmpty || _set == null) return;
    final id = queue.first.split('|')[1];
    Puzzle? p;
    for (final x in _set!.puzzles) {
      if (x.id == id) {
        p = x;
        break;
      }
    }
    if (p != null) _loadTactics(p);
  }

  String _uciOf(Move m) {
    if (m is NormalMove) {
      final promo = m.promotion == null ? '' : m.promotion!.name[0];
      return '${m.from.name}${m.to.name}$promo';
    }
    return '';
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
                  _pz = 0;
                  _feedback = null;
                  _wrong = [];
                  _set = null;
                  _puzzle = null;
                  _theme = null;
                });
                _loadSet();
              },
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'drills', label: Text('Book drills')),
              ButtonSegment(value: 'tactics', label: Text('Tactics')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() => _mode = s.first);
              if (_mode == 'tactics') {
                if (_set == null) {
                  _loadSet();
                } else {
                  _nextTactics();
                }
              }
            },
          ),
        ]),
        const SizedBox(height: 8),
        if (_mode == 'drills') _buildDrills() else _buildTactics(),
      ]),
    );
  }

  Widget _buildDrills() {
    final pzCount = puzzles.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: DropdownButton<int>(
            value: _lineIdx,
            isExpanded: true,
            items: [for (var i = 0; i < rep.lines.length; i++) DropdownMenuItem(value: i, child: Text(rep.lines[i].name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() { _lineIdx = v!; _pz = 0; _feedback = null; _wrong = []; }),
          ),
        ),
      ]),
      const SizedBox(height: 4),
      Text('Find the book move for ${rep.side}.', textAlign: TextAlign.center),
      ChessBoard(
        position: _drillsPos,
        whiteOnBottom: rep.side == 'white',
        onMove: _feedback == null ? _onMove : null,
      ),
      const SizedBox(height: 8),
      Text('Puzzle ${_pz + 1}/$pzCount · Streak ${widget.stats.puzzleStreak} (best ${widget.stats.puzzleBestStreak})'),
      if (_feedback != null) Text(_feedback!, style: const TextStyle(fontSize: 18)),
      if (_wrong.isNotEmpty) Text('Tried: ${_wrong.join(', ')}'),
      TextButton(onPressed: _next, child: const Text('Skip')),
      const SizedBox(height: 8),
      MoveList(history: puzzle.path),
    ]);
  }

  Position get _drillsPos {
    Position p = Chess.initial;
    for (final san in puzzle.path) {
      final m = p.parseSan(san);
      if (m != null) p = p.playUnchecked(m);
    }
    return p;
  }

  Widget _buildTactics() {
    final set = _set;
    final p = _puzzle;
    final s = widget.stats;
    if (set == null) {
      return const Text('Puzzle dataset not built yet. Run: dart run tools/build_puzzles.dart');
    }
    if (p == null || _pos == null) {
      return Text('No puzzles${_theme != null ? ' for theme "$_theme"' : ''} in this set.');
    }
    final queued = s.puzzleRetryQueue.where((k) => k.startsWith('$_repId|')).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Puzzle rating: ${s.puzzleRating} · Streak ${s.puzzleStreak} (best ${s.puzzleBestStreak})'),
      const SizedBox(height: 4),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          FilterChip(
            label: const Text('All'),
            selected: _theme == null,
            onSelected: (_) { setState(() => _theme = null); _nextTactics(); },
          ),
          for (final t in set.themes.take(12))
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: FilterChip(
                label: Text(t),
                selected: _theme == t,
                onSelected: (_) { setState(() => _theme = t); _nextTactics(); },
              ),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      Row(children: [
        TextButton(onPressed: set.daily() == null ? null : () => _loadTactics(set.daily()!, daily: true), child: const Text('Daily')),
        TextButton(onPressed: queued == 0 ? null : _retryQueued, child: Text('Retry ($queued)')),
        TextButton(onPressed: _showSolution, child: const Text('Show solution')),
        TextButton(onPressed: _nextTactics, child: const Text('Skip')),
      ]),
      const SizedBox(height: 4),
      if (_daily) const Text('Daily puzzle', style: TextStyle(color: Colors.deepPurple)),
      ChessBoard(
        position: _pos!,
        whiteOnBottom: p.solverSide == Side.white,
        onMove: _done || _replyPending ? null : _onTacticsMove,
      ),
      const SizedBox(height: 8),
      Text('${p.rating} · ${p.openingTags.join(', ')}'),
      Text('Themes: ${p.themes.join(', ')}', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
      if (_feedback != null) Text(_feedback!, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 8),
      if (_sans.isNotEmpty) MoveList(history: _sans),
    ]);
  }

  void _onMove(Move m, String san) {
    if (san == puzzle.answer) {
      _record(true);
      setState(() => _feedback = '✅ Correct!');
      Future.delayed(const Duration(milliseconds: 900), _next);
    } else {
      _record(false);
      setState(() {
        _feedback = '❌ Not the book move — try again.';
        _wrong = [..._wrong, san];
      });
    }
  }
}
