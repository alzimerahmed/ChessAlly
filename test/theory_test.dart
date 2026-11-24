import 'package:flutter_test/flutter_test.dart';
import 'package:opening_master/theory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TheorySet', () {
    late TheorySet london;
    setUpAll(() async {
      london = await TheorySet.load('london');
    });

    test('loads a non-trivial tree', () {
      expect(london.nodes.length, greaterThan(100));
    });

    test('childrenOf indexes correctly', () {
      expect(london.trunk, isNotEmpty);
      final rootKids = london.childrenOf(london.trunk);
      expect(rootKids, isNotEmpty);
      expect(rootKids.first.path.length, london.trunk.length + 1);
      // every child's parent path must match the requested path
      for (final n in london.nodes.take(50)) {
        final parent = n.path.sublist(0, n.path.length - 1);
        expect(london.childrenOf(parent).map((c) => c.key), contains(n.key));
      }
    });

    test('every node has valid stats and fen-consistent side to move', () {
      for (final n in london.nodes.take(100)) {
        expect(n.games, greaterThan(0));
        expect(n.white + n.draws + n.black, n.games);
        expect(n.whiteToMove, n.path.length.isEven);
      }
    });

    test('quizNodes match the requested side', () {
      for (final n in london.quizNodes('white')) {
        expect(n.whiteToMove, isTrue);
      }
      for (final n in london.quizNodes('black')) {
        expect(n.whiteToMove, isFalse);
      }
      expect(london.quizNodes('white'), isNotEmpty);
    });

    test('top continuations are sorted by games, max 3', () {
      for (final n in london.nodes) {
        expect(n.top.length, lessThanOrEqualTo(3));
        for (var i = 1; i < n.top.length; i++) {
          expect(n.top[i].games, lessThanOrEqualTo(n.top[i - 1].games));
        }
      }
    });

    test('all three repertoire datasets load', () async {
      for (final rep in ['caro-kann', 'french']) {
        final set = await TheorySet.load(rep);
        expect(set.nodes, isNotEmpty);
      }
    });
  });
}
