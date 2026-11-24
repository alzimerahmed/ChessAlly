import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Weekly goal targets.
const weeklyGameGoal = 5;
const weeklyPuzzleGoal = 30;

class Stats {
  int games = 0, wins = 0, losses = 0, draws = 0;
  int puzzlesAttempted = 0, puzzlesCorrect = 0, puzzleStreak = 0, puzzleBestStreak = 0;
  Map<String, int> linesSeen = {};
  Map<String, int> lineMastery = {};
  int dailyStreak = 0;
  String? lastDay;
  int reviewGames = 0;
  double reviewAccSum = 0;
  int puzzleRating = 800;
  List<String> puzzleRetryQueue = []; // "repId|puzzleId"

  // review accuracy on-book vs off-book (your moves only)
  double reviewBookSum = 0;
  int reviewBookCount = 0;
  double reviewOffBookSum = 0;
  int reviewOffBookCount = 0;

  // review accuracy per repertoire line (line id -> sums/counts)
  Map<String, double> reviewLineSum = {};
  Map<String, int> reviewLineCount = {};

  // weekly goals
  String? weekKey;
  int weekGames = 0, weekPuzzles = 0;

  // puzzle results per repertoire (for per-line mastery)
  Map<String, int> puzzleAttemptedByRep = {};
  Map<String, int> puzzleCorrectByRep = {};

  // board appearance
  String boardTheme = 'wood3';
  String pieceSet = 'cburnett';

  double get avgReviewAccuracy => reviewGames > 0 ? reviewAccSum / reviewGames : 0;
  double? get avgBookAccuracy => reviewBookCount > 0 ? reviewBookSum / reviewBookCount : null;
  double? get avgOffBookAccuracy => reviewOffBookCount > 0 ? reviewOffBookSum / reviewOffBookCount : null;

  double? reviewAccuracyForLine(String lineId) {
    final c = reviewLineCount[lineId] ?? 0;
    return c > 0 ? (reviewLineSum[lineId] ?? 0) / c : null;
  }

  /// Puzzle accuracy (0-100) for one repertoire, or null with no attempts.
  double? puzzleAccuracyForRep(String repId) {
    final a = puzzleAttemptedByRep[repId] ?? 0;
    if (a == 0) return null;
    return (puzzleCorrectByRep[repId] ?? 0) / a * 100;
  }

  void recordPuzzleResult(String repId, bool correct) {
    puzzleAttemptedByRep[repId] = (puzzleAttemptedByRep[repId] ?? 0) + 1;
    if (correct) {
      puzzleCorrectByRep[repId] = (puzzleCorrectByRep[repId] ?? 0) + 1;
    }
  }

  /// Composite per-line mastery: theory studied (40%), review accuracy in
  /// games where the line occurred (40%), puzzle accuracy of that repertoire
  /// (20%). Missing components are reweighted away.
  double lineMasteryV2(String lineId, String repId) {
    final parts = <(double, double)>[]; // (value 0-100, weight)
    final theory = (lineMastery[lineId] ?? 0).toDouble();
    if (lineMastery.containsKey(lineId)) parts.add((theory, 0.4));
    final review = reviewAccuracyForLine(lineId);
    if (review != null) parts.add((review, 0.4));
    final puzzle = puzzleAccuracyForRep(repId);
    if (puzzle != null) parts.add((puzzle, 0.2));
    if (parts.isEmpty) return 0;
    final wTotal = parts.fold<double>(0, (s, p) => s + p.$2);
    return parts.fold<double>(0, (s, p) => s + p.$1 * p.$2) / wTotal;
  }

  /// XP: games, puzzles, lines studied, reviews.
  int get xp {
    final linesStudied = linesSeen.values.where((v) => v > 0).length;
    return games * 10 + puzzlesCorrect * 5 + linesStudied * 25 + reviewGames * 20;
  }

  int get level => xp ~/ 500 + 1;
  double get levelProgress => (xp % 500) / 500;

  /// Opening-strength estimate: how much better you play on-book than off.
  /// Returns null when there is no review data yet.
  ({double book, double offBook, double edge})? get openingStrength {
    final book = avgBookAccuracy, off = avgOffBookAccuracy;
    if (book == null || off == null) return null;
    return (book: book, offBook: off, edge: book - off);
  }

  Map<String, dynamic> toJson() => {
        'games': games, 'wins': wins, 'losses': losses, 'draws': draws,
        'puzzlesAttempted': puzzlesAttempted, 'puzzlesCorrect': puzzlesCorrect,
        'puzzleStreak': puzzleStreak, 'puzzleBestStreak': puzzleBestStreak,
        'linesSeen': linesSeen, 'lineMastery': lineMastery,
        'dailyStreak': dailyStreak, 'lastDay': lastDay,
        'reviewGames': reviewGames, 'reviewAccSum': reviewAccSum,
        'puzzleRating': puzzleRating, 'puzzleRetryQueue': puzzleRetryQueue,
        'reviewBookSum': reviewBookSum, 'reviewBookCount': reviewBookCount,
        'reviewOffBookSum': reviewOffBookSum, 'reviewOffBookCount': reviewOffBookCount,
        'reviewLineSum': reviewLineSum, 'reviewLineCount': reviewLineCount,
        'weekKey': weekKey, 'weekGames': weekGames, 'weekPuzzles': weekPuzzles,
        'puzzleAttemptedByRep': puzzleAttemptedByRep, 'puzzleCorrectByRep': puzzleCorrectByRep,
        'boardTheme': boardTheme, 'pieceSet': pieceSet,
      };

  void fromJson(Map<String, dynamic> j) {
    games = j['games'] ?? 0;
    wins = j['wins'] ?? 0;
    losses = j['losses'] ?? 0;
    draws = j['draws'] ?? 0;
    puzzlesAttempted = j['puzzlesAttempted'] ?? 0;
    puzzlesCorrect = j['puzzlesCorrect'] ?? 0;
    puzzleStreak = j['puzzleStreak'] ?? 0;
    puzzleBestStreak = j['puzzleBestStreak'] ?? 0;
    linesSeen = Map<String, int>.from(j['linesSeen'] ?? {});
    lineMastery = Map<String, int>.from(j['lineMastery'] ?? {});
    dailyStreak = j['dailyStreak'] ?? 0;
    lastDay = j['lastDay'];
    reviewGames = j['reviewGames'] ?? 0;
    reviewAccSum = (j['reviewAccSum'] ?? 0).toDouble();
    puzzleRating = j['puzzleRating'] ?? 800;
    puzzleRetryQueue = List<String>.from(j['puzzleRetryQueue'] ?? []);
    reviewBookSum = (j['reviewBookSum'] ?? 0).toDouble();
    reviewBookCount = j['reviewBookCount'] ?? 0;
    reviewOffBookSum = (j['reviewOffBookSum'] ?? 0).toDouble();
    reviewOffBookCount = j['reviewOffBookCount'] ?? 0;
    reviewLineSum = (j['reviewLineSum'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, (v as num).toDouble()));
    reviewLineCount = Map<String, int>.from(j['reviewLineCount'] ?? {});
    weekKey = j['weekKey'];
    weekGames = j['weekGames'] ?? 0;
    weekPuzzles = j['weekPuzzles'] ?? 0;
    puzzleAttemptedByRep = Map<String, int>.from(j['puzzleAttemptedByRep'] ?? {});
    puzzleCorrectByRep = Map<String, int>.from(j['puzzleCorrectByRep'] ?? {});
    boardTheme = j['boardTheme'] ?? 'wood3';
    pieceSet = j['pieceSet'] ?? 'cburnett';
  }

  void touchDaily() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastDay == today) return;
    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    dailyStreak = lastDay == yesterday ? dailyStreak + 1 : 1;
    lastDay = today;
  }

  /// Roll over weekly goal counters when the week changes.
  void touchWeekly() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final wk = '${now.year}-W${dayOfYear ~/ 7}';
    if (weekKey != wk) {
      weekKey = wk;
      weekGames = 0;
      weekPuzzles = 0;
    }
  }
}

const _key = 'opening-master-stats';

Future<Stats> loadStats() async {
  final s = Stats();
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw != null) {
    try {
      s.fromJson(jsonDecode(raw));
    } catch (_) {}
  }
  return s;
}

Future<void> saveStats(Stats s) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_key, jsonEncode(s.toJson()));
}
