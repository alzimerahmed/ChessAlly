import 'package:flutter_test/flutter_test.dart';
import 'package:opening_master/puzzles.dart';

const fenWhiteToMove = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const fenBlackToMove = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1';

Puzzle p(String id, String fen, {int rating = 1200, List<String> themes = const []}) => Puzzle(
      id: id,
      fen: fen,
      solutionMoves: const ['e2e4'],
      rating: rating,
      popularity: 100,
      themes: themes,
      openingTags: const [],
    );

void main() {
  group('Puzzle', () {
    test('solverSide comes from the FEN', () {
      expect(p('a', fenWhiteToMove).solverSide.name, 'white');
      expect(p('b', fenBlackToMove).solverSide.name, 'black');
    });
  });

  group('PuzzleSet', () {
    test('themes are sorted by frequency', () {
      final set = PuzzleSet('x', [
        p('1', fenWhiteToMove, themes: ['mate', 'fork']),
        p('2', fenWhiteToMove, themes: ['mate']),
        p('3', fenWhiteToMove, themes: ['pin']),
      ]);
      expect(set.themes, ['mate', 'fork', 'pin']);
    });
    test('daily is deterministic for the same day', () {
      final set = PuzzleSet('x', [p('1', fenWhiteToMove), p('2', fenWhiteToMove), p('3', fenWhiteToMove)]);
      expect(set.daily()!.id, set.daily()!.id);
    });
  });

  group('updatePuzzleRating', () {
    test('solving a much harder puzzle gains a lot', () {
      final gain = updatePuzzleRating(800, 1600, true) - 800;
      expect(gain, greaterThan(25));
    });
    test('failing a much easier puzzle loses a lot', () {
      final loss = 800 - updatePuzzleRating(800, 800, false);
      expect(loss, greaterThan(10));
    });
    test('solving an equal puzzle gains ~16', () {
      expect(updatePuzzleRating(800, 800, true) - 800, 16);
    });
  });
}
