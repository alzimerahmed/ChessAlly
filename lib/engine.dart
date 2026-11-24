import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';

class EvalResult {
  /// centipawns from White's perspective (mate encoded as +/-10000)
  final int cp;
  final int? mate;
  final String bestMoveUci;
  const EvalResult(this.cp, this.mate, this.bestMoveUci);
}

/// Singleton wrapper around the lichess stockfish package (native engine via FFI).
class Engine {
  static final Engine instance = Engine._();
  Engine._();

  Stockfish? _sf;
  Completer<void>? _ready;
  final _evalWaiters = <_EvalJob>[];
  StreamSubscription<String>? _sub;
  Completer<void> _evalLock = Completer<void>()..complete();

  Future<void> init() {
    _ready ??= Completer<void>();
    if (_ready!.isCompleted) return _ready!.future;
    if (_sf == null) {
      _sf = Stockfish();
      _sub = _sf!.stdout.listen(_onLine);
      // wait until the engine isolate reports ready before sending UCI
      late final VoidCallback listener;
      listener = () {
        if (_sf!.state.value == StockfishState.ready) {
          _sf!.state.removeListener(listener);
          _sf!.stdin = 'uci';
        } else if (_sf!.state.value == StockfishState.error) {
          _sf!.state.removeListener(listener);
          if (!_ready!.isCompleted) _ready!.completeError(StateError('Stockfish failed to start'));
        }
      };
      _sf!.state.addListener(listener);
      listener();
    }
    return _ready!.future;
  }

  void _onLine(String line) {
    if (line == 'uciok') {
      _sf!.stdin = 'isready';
    } else if (line == 'readyok') {
      if (_ready != null && !_ready!.isCompleted) _ready!.complete();
    } else if (_evalWaiters.isNotEmpty) {
      final job = _evalWaiters.first;
      job.onLine(line);
      if (job.isDone) {
        _evalWaiters.remove(job);
        _evalLock.complete();
      }
    }
  }

  /// Evaluate a position. Serialized — safe to call repeatedly.
  Future<EvalResult> eval(String fen, {int depth = 12}) async {
    await init();
    await _evalLock.future;
    _evalLock = Completer<void>();
    final job = _EvalJob(fen, depth);
    _evalWaiters.add(job);
    _sf!.stdin = 'position fen $fen';
    _sf!.stdin = 'go depth $depth';
    return job.completer.future;
  }

  void dispose() {
    _sub?.cancel();
    _sf?.dispose();
    _sf = null;
    _ready = null;
  }
}

class _EvalJob {
  final String fen;
  final int depth;
  final completer = Completer<EvalResult>();
  int _cp = 0;
  int? _mate;
  String _best = '';
  bool get isDone => completer.isCompleted;

  _EvalJob(this.fen, this.depth);

  void onLine(String line) {
    if (line.startsWith('info') && line.contains(' pv ')) {
      final cpMatch = RegExp(r'score cp (-?\d+)').firstMatch(line);
      final mateMatch = RegExp(r'score mate (-?\d+)').firstMatch(line);
      final pv = RegExp(r' pv (\S+)').firstMatch(line);
      final whiteToMove = fen.contains(' w ');
      if (mateMatch != null) {
        final m = int.parse(mateMatch.group(1)!);
        _mate = whiteToMove ? m : -m;
        _cp = m > 0 ? 10000 : -10000;
      } else if (cpMatch != null) {
        final c = int.parse(cpMatch.group(1)!);
        _cp = whiteToMove ? c : -c;
        _mate = null;
      }
      if (pv != null) _best = pv.group(1)!;
    } else if (line.startsWith('bestmove')) {
      final bm = line.split(' ')[1];
      if (bm != '(none)') _best = bm;
      completer.complete(EvalResult(_cp, _mate, _best));
    }
  }
}
