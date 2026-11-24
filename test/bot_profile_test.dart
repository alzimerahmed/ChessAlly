import 'package:flutter_test/flutter_test.dart';
import 'package:opening_master/book.dart';
import 'package:opening_master/game_controller.dart';

BookMove bm(String san, int games, {int white = 50, int draws = 30, int black = 20, List<BookMove> children = const []}) =>
    BookMove(san: san, uci: '', games: games, white: white, draws: draws, black: black, avg: 1600, children: children);

MasterBook testBook() => MasterBook('test', const [], [
      bm('d4', 10000, white: 5500, children: [
        bm('Nf6', 9000, children: [
          bm('Bf4', 8000, white: 5200),
          bm('e3', 100, white: 40), // rare edge-case move
        ]),
      ]),
    ]);

void main() {
  final book = testBook();
  final path = ['d4', 'Nf6'];

  group('BotProfile book behavior', () {
    test('beginner always plays the most popular move', () {
      for (var i = 0; i < 20; i++) {
        expect(book.mainline(path)!.san, 'Bf4');
      }
    });

    test('sharp can play the rare move (inverse-frequency weighting)', () {
      final picks = <String>[];
      for (var i = 0; i < 200; i++) {
        picks.add(book.pickRare(path)!.san);
      }
      expect(picks.toSet(), containsAll(['Bf4', 'e3']));
      // rare move should dominate: ~99% expected with inverse-frequency weighting
      final rare = picks.where((s) => s == 'e3').length;
      expect(rare, greaterThan(100));
    });

    test('weighted pick strongly favors the popular move', () {
      final picks = <String>[];
      for (var i = 0; i < 200; i++) {
        picks.add(book.pickWeighted(path)!.san);
      }
      expect(picks, contains('Bf4'));
      final rareCount = picks.where((s) => s == 'e3').length;
      expect(rareCount, lessThan(10)); // ~1.2% expected
    });

    test('master picks the statistically strongest move', () {
      expect(book.best(path, minGames: 200)!.san, 'Bf4');
    });

    test('best is side-aware (mover perspective)', () {
      final b = MasterBook('side', const [], [
        bm('d4', 2000, white: 1100, draws: 500, black: 400),
        bm('e4', 2000, white: 900, draws: 500, black: 600, children: [
          bm('c5', 1000, white: 600, draws: 200, black: 200), // good for White
          bm('e5', 1000, white: 300, draws: 200, black: 500), // good for Black
        ]),
      ]);
      expect(b.best(const [])!.san, 'd4'); // White to move
      expect(b.best(const ['e4'])!.san, 'e5'); // Black to move
    });

    test('master falls back to weighted when no move meets minGames', () {
      final sparse = MasterBook('sparse', const [], [
        bm('e4', 100, children: [bm('e5', 50), bm('c5', 40)]),
      ]);
      expect(sparse.best(['e4'], minGames: 200), isNull);
      expect(sparse.pickWeighted(['e4']), isNotNull);
    });

    test('profiles have distinct depths and labels', () {
      expect(BotProfile.beginner.depth, 2);
      expect(BotProfile.master.depth, 14);
      expect(BotProfile.values.map((p) => p.label).toSet().length, BotProfile.values.length);
    });

    test('pickRare/pickWeighted return null off-book', () {
      expect(book.pickRare(['c4']), isNull);
      expect(book.pickWeighted(['c4']), isNull);
      expect(book.mainline(['c4']), isNull);
    });
  });
}
