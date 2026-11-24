import 'dart:async';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import '../board.dart';
import '../data.dart';
import '../engine.dart';
import '../game_controller.dart';
import '../stats.dart';
import 'review.dart';

const _profiles = BotProfile.values;

class PlayScreen extends StatefulWidget {
  final Stats stats;
  final void Function(Stats) setStats;
  const PlayScreen({super.key, required this.stats, required this.setStats});
  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final _game = GameController();
  String _repId = 'london';
  BotProfile _profile = BotProfile.club;
  bool _bookBot = true;
  Timer? _clock;
  int _wTime = 300, _bTime = 300;
  bool _recorded = false;
  bool _reviewed = false;
  Side? _flagged; // side that ran out of time
  String? _lastSource;

  Repertoire get rep => repById(_repId);
  Side get mySide => rep.side == 'white' ? Side.white : Side.black;
  bool get myTurn => _game.position.turn == mySide;

  @override
  void initState() {
    super.initState();
    Engine.instance.init();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_game.isOver || _flagged != null) return;
      setState(() {
        if (_game.position.turn == Side.white) {
          _wTime = _wTime > 0 ? _wTime - 1 : 0;
          if (_wTime == 0) _flagged = Side.white;
        } else {
          _bTime = _bTime > 0 ? _bTime - 1 : 0;
          if (_bTime == 0) _flagged = Side.black;
        }
      });
      if (_flagged != null) _recordResult();
    });
    _game.loadBook(repById(_repId)).then((_) => mounted ? setState(() {}) : null);
    _maybeAi();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _maybeAi() async {
    if (_game.isOver || myTurn) return;
    setState(() => _game.thinking = true);
    if (_bookBot) {
      final r = await _game.aiMoveBook(rep, profile: _profile);
      _lastSource = r?.source;
    } else {
      final san = await _game.aiMove(depth: _profile.depth);
      _lastSource = san == null ? null : 'engine';
    }
    if (!mounted) return;
    setState(() {});
    _recordResult();
  }

  void _recordResult() {
    if ((!_game.isOver && _flagged == null) || _recorded) return;
    _recorded = true;
    final winner = _flagged != null
        ? _flagged!.opposite // flag = loss on time
        : _game.outcome?.winner;
    final s = widget.stats;
    s.games++;
    if (winner == null) {
      s.draws++;
    } else if (winner == mySide) {
      s.wins++;
    } else {
      s.losses++;
    }
    s.touchDaily();
    s.touchWeekly();
    s.weekGames++;
    saveStats(s);
    widget.setStats(s);
  }

  void _onMove(Move m, String san) {
    setState(() {
      _game.move(m, san);
    });
    _maybeAi();
    _recordResult();
  }

  void _newGame() {
    setState(() {
      _game.reset();
      _wTime = 300;
      _bTime = 300;
      _recorded = false;
      _reviewed = false;
      _flagged = null;
      _lastSource = null;
    });
    _maybeAi();
  }

  String _fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bookNode = followPath(rep, _game.history);
    final result = _game.isOver || _flagged != null
        ? (_flagged != null
            ? '${_flagged == Side.white ? 'White' : 'Black'} ran out of time — ${_flagged == mySide ? 'you lost.' : 'you won.'}'
            : _game.outcome?.winner == mySide
                ? 'You won!'
                : _game.outcome?.winner == null
                    ? 'Draw.'
                    : 'You lost.')
        : null;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ListView(
        children: [
          Row(children: [
            Expanded(
              child: DropdownButton<String>(
                value: _repId,
                isExpanded: true,
                items: repertoires.map((r) => DropdownMenuItem(value: r.id, child: Text('${r.name} (${r.side})'))).toList(),
                onChanged: (v) {
                  setState(() {
                    _repId = v!;
                    // side and book change with the repertoire — start fresh
                    _game.reset();
                    _wTime = 300;
                    _bTime = 300;
                    _recorded = false;
                    _reviewed = false;
                    _flagged = null;
                    _lastSource = null;
                  });
                  _game.loadBook(repById(_repId)).then((_) => mounted ? setState(() {}) : null);
                  _maybeAi();
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<BotProfile>(
              value: _profile,
              items: [for (final p in _profiles) DropdownMenuItem(value: p, child: Text('${p.label} (d${p.depth})'))],
              onChanged: (v) => setState(() => _profile = v!),
            ),
          ]),
          Row(children: [
            const Text('Bot: '),
            Switch(
              value: _bookBot,
              onChanged: (v) => setState(() => _bookBot = v),
            ),
            Text(_bookBot ? 'Book bot (plays your openings)' : 'Pure engine'),
            if (_lastSource != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text('last: $_lastSource', style: const TextStyle(color: Colors.blueGrey)),
              ),
          ]),
          const SizedBox(height: 4),
          Text('B ${_fmt(_bTime)}  —  W ${_fmt(_wTime)}', textAlign: TextAlign.center),
          const SizedBox(height: 4),
          ChessBoard(
            position: _game.position,
            whiteOnBottom: mySide == Side.white,
            onMove: myTurn && !_game.isOver && _flagged == null ? _onMove : null,
            lastMove: _game.lastMoveSquares,
          ),
          const SizedBox(height: 8),
          Row(children: [
            FilledButton.tonal(onPressed: () => setState(() => _game.undoTwo()), child: const Text('Undo')),
            const SizedBox(width: 8),
            FilledButton(onPressed: _newGame, child: const Text('New game')),
            if (_game.thinking) const Padding(padding: EdgeInsets.only(left: 8), child: Text('AI thinking…')),
          ]),
          const SizedBox(height: 8),
          if (result != null) ...[
            Text(result, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            FilledButton.tonal(
              onPressed: _reviewed ? null : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewScreen(
                    history: List.of(_game.history),
                    repId: _repId,
                    mySide: mySide,
                    onAccuracy: (sum) {
                      final s = widget.stats;
                      s.reviewGames++;
                      s.reviewAccSum += sum.overall;
                      if (sum.bookAcc != null) {
                        s.reviewBookSum += sum.bookAcc!;
                        s.reviewBookCount++;
                      }
                      if (sum.offBookAcc != null) {
                        s.reviewOffBookSum += sum.offBookAcc!;
                        s.reviewOffBookCount++;
                      }
                      final lineId = sum.lineId;
                      if (lineId != null) {
                        s.reviewLineSum[lineId] = (s.reviewLineSum[lineId] ?? 0) + sum.overall;
                        s.reviewLineCount[lineId] = (s.reviewLineCount[lineId] ?? 0) + 1;
                      }
                      saveStats(s);
                      widget.setStats(s);
                      _reviewed = true;
                    },
                  ),
                ),
              ),
              child: const Text('Review game'),
            ),
          ],
          Text(
            bookNode != null ? 'In book (${_game.history.length} plies)' : 'Off book',
            style: TextStyle(color: bookNode != null ? Colors.green : Colors.orange),
          ),
          const SizedBox(height: 8),
          Text('Moves', style: Theme.of(context).textTheme.titleSmall),
          MoveList(history: _game.history),
        ],
      ),
    );
  }
}

class MoveList extends StatelessWidget {
  final List<String> history;
  const MoveList({super.key, required this.history});
  @override
  Widget build(BuildContext context) {
    final rows = <String>[];
    for (var i = 0; i < history.length; i += 2) {
      rows.add('${i ~/ 2 + 1}. ${history[i]}${i + 1 < history.length ? ' ${history[i + 1]}' : ''}');
    }
    return Text(rows.join('   '), style: const TextStyle(fontFamily: 'monospace'));
  }
}
