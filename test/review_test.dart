import 'package:flutter_test/flutter_test.dart';
import 'package:dartchess/dartchess.dart';
import 'package:opening_master/review.dart';

void main() {
  group('classifyMove', () {
    test('book overrides everything', () {
      expect(classifyMove(500, isBook: true), MoveTag.book);
    });
    test('thresholds', () {
      expect(classifyMove(0, isBook: false), MoveTag.best);
      expect(classifyMove(25, isBook: false), MoveTag.excellent);
      expect(classifyMove(50, isBook: false), MoveTag.good);
      expect(classifyMove(100, isBook: false), MoveTag.inaccuracy);
      expect(classifyMove(300, isBook: false), MoveTag.mistake);
      expect(classifyMove(301, isBook: false), MoveTag.blunder);
    });
  });

  group('winPercent', () {
    test('symmetric around equal position', () {
      expect(winPercent(0), closeTo(50, 0.01));
      expect(winPercent(200) + winPercent(-200), closeTo(100, 0.01));
    });
    test('more material = higher win%', () {
      expect(winPercent(500), greaterThan(winPercent(100)));
    });
  });

  group('moveAccuracy', () {
    test('no drop = perfect accuracy', () {
      expect(moveAccuracy(60, 60), closeTo(100, 0.01));
    });
    test('big drop = low accuracy', () {
      expect(moveAccuracy(90, 10), lessThan(50));
    });
  });

  group('GameReview', () {
    test('keyMoments sorted by cp loss, no-loss moves excluded', () {
      ReviewedMove m(int ply, int loss) => ReviewedMove(
            ply: ply,
            san: 'e4',
            side: Side.white,
            cpLoss: loss,
            tag: classifyMove(loss, isBook: false),
            isMiss: false,
            bestMoveUci: '',
            accuracy: 90,
          );
      final review = GameReview(
        moves: [m(0, 10), m(1, 400), m(2, 0), m(3, 120)],
        whiteAccuracy: 90,
        blackAccuracy: 80,
      );
      final keys = review.keyMoments();
      expect(keys.map((k) => k.ply), [1, 3, 0]);
      expect(review.myAccuracy(Side.white), 90);
      expect(review.myAccuracy(Side.black), 80);
    });
  });
}
