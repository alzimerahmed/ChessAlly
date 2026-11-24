import 'dart:math';
import 'package:dartchess/dartchess.dart';
import 'book.dart';
import 'engine.dart';

enum MoveTag { book, best, excellent, good, inaccuracy, mistake, blunder }

class ReviewedMove {
  final int ply; // 0-based index into the SAN history
  final String san;
  final Side side;
  final int cpLoss;
  final MoveTag tag;
  final bool isMiss;
  final String bestMoveUci;
  final double accuracy;
  const ReviewedMove({
    required this.ply,
    required this.san,
    required this.side,
    required this.cpLoss,
    required this.tag,
    required this.isMiss,
    required this.bestMoveUci,
    required this.accuracy,
  });
}

class GameReview {
  final List<ReviewedMove> moves;
  final double whiteAccuracy;
  final double blackAccuracy;
  const GameReview({
    required this.moves,
    required this.whiteAccuracy,
    required this.blackAccuracy,
  });

  double myAccuracy(Side side) => side == Side.white ? whiteAccuracy : blackAccuracy;

  /// Biggest swings (largest cp loss first), capped at [n].
  List<ReviewedMove> keyMoments({int n = 3}) {
    final sorted = [...moves]..sort((a, b) => b.cpLoss.compareTo(a.cpLoss));
    return sorted.where((m) => m.cpLoss > 0).take(n).toList();
  }
}

/// Chess.com-style classification by centipawn loss.
MoveTag classifyMove(int cpLoss, {required bool isBook}) {
  if (isBook) return MoveTag.book;
  if (cpLoss <= 0) return MoveTag.best;
  if (cpLoss <= 25) return MoveTag.excellent;
  if (cpLoss <= 50) return MoveTag.good;
  if (cpLoss <= 100) return MoveTag.inaccuracy;
  if (cpLoss <= 300) return MoveTag.mistake;
  return MoveTag.blunder;
}

/// Win probability (%) from White's perspective, Lichess conversion.
double winPercent(int cp) {
  final clamped = cp.clamp(-1500, 1500).toDouble();
  return (50 + 50 * (2 / (1 + exp(-0.00368208 * clamped)) - 1)).clamp(0.0, 100.0);
}

/// Per-move accuracy from the win-percent drop caused by the move.
double moveAccuracy(double winPercentBefore, double winPercentAfter) {
  final loss = max(0.0, winPercentBefore - winPercentAfter);
  return (103.1668 * exp(-0.04354 * loss) - 3.1669).clamp(0.0, 100.0);
}

/// Evaluate every position of a game and classify each move.
/// [onProgress] reports (done, total) for UI progress bars.
Future<GameReview> analyzeGame(
  List<String> history, {
  MasterBook? book,
  int depth = 12,
  void Function(int done, int total)? onProgress,
}) async {
  // Replay to get every position along the game.
  final positions = <Position>[Chess.initial];
  final played = <Move>[];
  Position pos = Chess.initial;
  for (final san in history) {
    final m = pos.parseSan(san);
    if (m == null) break;
    pos = pos.makeSan(m).$1;
    positions.add(pos);
    played.add(m);
  }

  // One eval per position; loss for ply i = eval(i) vs eval(i+1).
  final evals = <EvalResult>[];
  final total = positions.length;
  for (var i = 0; i < total; i++) {
    evals.add(await Engine.instance.eval(positions[i].fen, depth: depth));
    onProgress?.call(i + 1, total);
  }

  final reviewed = <ReviewedMove>[];
  for (var i = 0; i < played.length; i++) {
    final side = i.isEven ? Side.white : Side.black;
    final before = evals[i], after = evals[i + 1];
    final cpBefore = side == Side.white ? before.cp : -before.cp;
    final cpAfter = side == Side.white ? after.cp : -after.cp;
    final cpLoss = max(0, cpBefore - cpAfter);
    final isBook = book != null &&
        book.movesAt(history.sublist(0, i)).any((b) => b.san == history[i]);
    final isMiss = cpBefore >= 300 && cpAfter <= 0;
    final acc = moveAccuracy(
      side == Side.white ? winPercent(before.cp) : 100 - winPercent(before.cp),
      side == Side.white ? winPercent(after.cp) : 100 - winPercent(after.cp),
    );
    reviewed.add(ReviewedMove(
      ply: i,
      san: history[i],
      side: side,
      cpLoss: cpLoss,
      tag: classifyMove(cpLoss, isBook: isBook),
      isMiss: isMiss,
      bestMoveUci: before.bestMoveUci,
      accuracy: acc,
    ));
  }

  double avg(Side s) {
    final ms = reviewed.where((m) => m.side == s).toList();
    if (ms.isEmpty) return 0;
    return ms.fold<double>(0, (a, m) => a + m.accuracy) / ms.length;
  }

  return GameReview(
    moves: reviewed,
    whiteAccuracy: avg(Side.white),
    blackAccuracy: avg(Side.black),
  );
}
