import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opening_master/data.dart';

void main() {
  group('repertoire content', () {
    test('every line is fully legal SAN', () {
      for (final rep in repertoires) {
        for (final line in rep.lines) {
          Position p = Chess.initial;
          for (final san in line.moves) {
            final m = p.parseSan(san);
            expect(m, isNotNull, reason: '${rep.id}/${line.id}: "$san" illegal after ${p.fen}');
            p = p.playUnchecked(m!);
          }
        }
      }
    });

    test('every tree path is legal SAN', () {
      void walk(TreeNode node, List<String> path, String repId) {
        Position p = Chess.initial;
        for (final san in path) {
          final m = p.parseSan(san);
          expect(m, isNotNull, reason: '$repId path $path: "$san" illegal');
          p = p.playUnchecked(m!);
        }
        for (final c in node.children) {
          walk(c, [...path, c.move!], repId);
        }
      }

      for (final rep in repertoires) {
        walk(rep.tree, rep.trunk, rep.id);
      }
    });

    test('each line stays on the repertoire tree', () {
      for (final rep in repertoires) {
        for (final line in rep.lines) {
          expect(followPath(rep, line.moves), isNotNull, reason: line.id);
        }
      }
    });

    test('trees cover the main opponent replies', () {
      final l = repById('london');
      for (final reply in ['Nf6', 'c5', 'e6', 'g6', 'c6']) {
        expect(bookReplies(l, l.trunk).map((c) => c.move), contains(reply));
      }
      final ck = repById('caro-kann');
      for (final reply in ['Nc3', 'exd5', 'e5', 'Nf3']) {
        expect(bookReplies(ck, ck.trunk).map((c) => c.move), contains(reply));
      }
      final fr = repById('french');
      for (final reply in ['Nc3', 'Nd2', 'exd5', 'e5']) {
        expect(bookReplies(fr, fr.trunk).map((c) => c.move), contains(reply));
      }
    });
  });

  group('puzzle generation', () {
    test('puzzles only target the repertoire side and are legal', () {
      for (final rep in repertoires) {
        for (final line in rep.lines) {
          final puzzles = puzzlePositions(line, rep.side);
          expect(puzzles, isNotEmpty);
          for (final p in puzzles) {
            final moverIsWhite = p.path.length % 2 == 0;
            expect((rep.side == 'white') == moverIsWhite, isTrue);
            Position pos = Chess.initial;
            for (final san in p.path) {
              pos = pos.playUnchecked(pos.parseSan(san)!);
            }
            expect(pos.parseSan(p.answer), isNotNull);
          }
        }
      }
    });
  });
}
