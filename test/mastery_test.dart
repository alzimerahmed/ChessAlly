import 'package:flutter_test/flutter_test.dart';
import 'package:opening_master/data.dart';
import 'package:opening_master/stats.dart';

Stats statsWith(Map<String, dynamic> overrides) {
  final s = Stats();
  final base = {
    'games': 0, 'wins': 0, 'losses': 0, 'draws': 0,
    'puzzlesAttempted': 0, 'puzzlesCorrect': 0,
    'puzzleStreak': 0, 'puzzleBestStreak': 0,
    'linesSeen': <String, int>{}, 'lineMastery': <String, int>{},
    'dailyStreak': 0, 'reviewGames': 0, 'reviewAccSum': 0.0,
    'puzzleRating': 800, 'puzzleRetryQueue': <String>[],
    'reviewBookSum': 0.0, 'reviewBookCount': 0,
    'reviewOffBookSum': 0.0, 'reviewOffBookCount': 0,
    'reviewLineSum': <String, double>{}, 'reviewLineCount': <String, int>{},
    'weekGames': 0, 'weekPuzzles': 0,
  };
  final j = {...base, ...overrides};
  s.fromJson(j);
  return s;
}

void main() {
  group('matchLineId', () {
    final london = repById('london');
    test('matches a line followed exactly', () {
      final line = london.lines.first;
      expect(matchLineId(london, List.of(line.moves)), line.id);
    });
    test('matches a line still in progress (prefix)', () {
      final line = london.lines.first;
      expect(matchLineId(london, line.moves.sublist(0, london.trunk.length + 2)), isNotNull);
    });
    test('returns null before the trunk is complete', () {
      expect(matchLineId(london, ['d4']), isNull);
    });
    test('returns null for a foreign opening', () {
      expect(matchLineId(london, ['e4', 'e5', 'Nf3']), isNull);
    });
  });

  group('lineMasteryV2', () {
    test('theory-only line uses theory weight alone', () {
      final s = statsWith({'lineMastery': {'ld-main': 50}});
      final m = s.lineMasteryV2('ld-main', 'london'); // no puzzle data -> dropped
      expect(m, 50.0);
    });

    test('full components blend 40/40/20', () {
      final s = statsWith({
        'lineMastery': {'x': 80},
        'reviewLineSum': {'x': 90.0},
        'reviewLineCount': {'x': 1},
        'puzzleAttemptedByRep': {'london': 10},
        'puzzleCorrectByRep': {'london': 8}, // 80% london puzzle accuracy
      });
      final m = s.lineMasteryV2('x', 'london');
      expect(m, closeTo(0.4 * 80 + 0.4 * 90 + 0.2 * 80, 0.01));
    });

    test('puzzle component is per-repertoire', () {
      final s = statsWith({
        'lineMastery': {'x': 80},
        'puzzleAttemptedByRep': {'caro-kann': 10},
        'puzzleCorrectByRep': {'caro-kann': 10}, // 100% but for a different rep
      });
      // london has no puzzle data -> component dropped, theory reweighted
      final m = s.lineMasteryV2('x', 'london');
      expect(m, 80.0);
      expect(s.lineMasteryV2('x', 'caro-kann'), closeTo((80 * 0.4 + 100 * 0.2) / 0.6, 0.01));
    });

    test('missing review component reweights', () {
      final s = statsWith({
        'lineMastery': {'x': 80},
        'puzzleAttemptedByRep': {'london': 10},
        'puzzleCorrectByRep': {'london': 10}, // 100%
      });
      final m = s.lineMasteryV2('x', 'london');
      expect(m, closeTo((80 * 0.4 + 100 * 0.2) / 0.6, 0.01));
    });

    test('no components = 0', () {
      expect(statsWith({}).lineMasteryV2('x', 'london'), 0);
    });
  });

  group('XP & level', () {
    test('formula and level thresholds', () {
      final s = statsWith({
        'games': 2, // 20
        'puzzlesCorrect': 4, // 20
        'linesSeen': {'a': 1, 'b': 2}, // 2 studied lines -> 50
        'reviewGames': 1, // 20
      });
      expect(s.xp, 110);
      expect(s.level, 1);
      expect(s.levelProgress, closeTo(110 / 500, 0.001));
    });

    test('level 2 at 500 xp', () {
      final s = statsWith({'games': 50}); // 500 xp
      expect(s.level, 2);
      expect(s.levelProgress, 0);
    });
  });

  group('opening strength', () {
    test('needs both book and off-book data', () {
      expect(statsWith({}).openingStrength, isNull);
      final onlyBook = statsWith({'reviewBookSum': 90.0, 'reviewBookCount': 1});
      expect(onlyBook.openingStrength, isNull);
    });

    test('edge = book - off-book', () {
      final s = statsWith({
        'reviewBookSum': 180.0, 'reviewBookCount': 2, // avg 90
        'reviewOffBookSum': 60.0, 'reviewOffBookCount': 1, // 60
      });
      final st = s.openingStrength!;
      expect(st.book, 90.0);
      expect(st.offBook, 60.0);
      expect(st.edge, 30.0);
    });
  });

  group('weekly goals', () {
    test('touchWeekly rolls over on week change', () {
      final s = Stats();
      s.touchWeekly();
      s.weekGames = 3;
      s.weekPuzzles = 20;
      // same week: no reset
      s.touchWeekly();
      expect(s.weekGames, 3);
      // simulate an old week
      s.weekKey = '1999-W0';
      s.touchWeekly();
      expect(s.weekGames, 0);
      expect(s.weekPuzzles, 0);
      expect(s.weekKey, isNot('1999-W0'));
    });

    test('review per-line accuracy averages', () {
      final s = statsWith({
        'reviewLineSum': {'x': 80.0, 'y': 100.0},
        'reviewLineCount': {'x': 2, 'y': 1},
      });
      expect(s.reviewAccuracyForLine('x'), 40.0);
      expect(s.reviewAccuracyForLine('y'), 100.0);
      expect(s.reviewAccuracyForLine('z'), isNull);
    });
  });
}
