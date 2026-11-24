import 'package:flutter_test/flutter_test.dart';
import 'package:dartchess/dartchess.dart';
import 'package:opening_master/puzzles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final rep in ['london', 'caro-kann', 'french']) {
    group('puzzle dataset $rep', () {
      late PuzzleSet set;
      setUpAll(() async {
        set = await PuzzleSet.load(rep);
      });

      test('is non-trivial', () {
        expect(set.puzzles.length, greaterThanOrEqualTo(100));
      });

      test('every puzzle is legal and solvable', () {
        for (final p in set.puzzles) {
          Position pos = Chess.fromSetup(Setup.parseFen(p.fen));
          expect(p.solutionMoves, isNotEmpty, reason: p.id);
          for (var i = 0; i < p.solutionMoves.length; i++) {
            final uci = p.solutionMoves[i];
            final m = NormalMove.fromUci(uci);
            final legal = pos.isLegal(m);
            expect(legal, isTrue, reason: '${p.id} illegal $uci at ply $i from ${p.fen}');
            pos = pos.playUnchecked(m);
          }
        }
      });

      test('first solution move is played by the side to move', () {
        for (final p in set.puzzles) {
          final pos = Chess.fromSetup(Setup.parseFen(p.fen));
          final m = NormalMove.fromUci(p.solutionMoves.first);
          expect(pos.board.roleAt(m.from), isNotNull, reason: p.id);
          expect(pos.turn, pos.board.sideAt(m.from), reason: p.id);
        }
      });

      test('Lichess convention: solver plays the second move (opposite side)', () {
        for (final p in set.puzzles) {
          if (p.solutionMoves.length < 2) continue;
          final pos = Chess.fromSetup(Setup.parseFen(p.fen));
          final opp = NormalMove.fromUci(p.solutionMoves[0]);
          final solverPos = pos.playUnchecked(opp);
          final solverMove = NormalMove.fromUci(p.solutionMoves[1]);
          expect(solverPos.turn, solverPos.board.sideAt(solverMove.from), reason: p.id);
          expect(p.solverSide, solverPos.turn, reason: p.id);
        }
      });

      test('ratings are club-realistic', () {
        for (final p in set.puzzles) {
          expect(p.rating, lessThanOrEqualTo(1800), reason: p.id);
          expect(p.rating, greaterThan(0), reason: p.id);
        }
      });
    });
  }
}
