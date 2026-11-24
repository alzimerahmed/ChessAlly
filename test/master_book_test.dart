import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opening_master/book.dart';
import 'package:opening_master/data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('master book assets load and are non-trivial', () async {
    for (final rep in repertoires) {
      final book = await MasterBook.load(rep.id, trunk: rep.trunk);
      expect(book.root, isNotEmpty, reason: rep.id);
      // total games captured should be large (real master data)
      final totalGames = book.root.fold<int>(0, (s, m) => s + m.games);
      expect(totalGames, greaterThan(100000), reason: '${rep.id} dataset too small');
    }
  });

  test('every dataset path is legal chess', () async {
    for (final rep in repertoires) {
      final book = await MasterBook.load(rep.id, trunk: rep.trunk);
      void walk(List<BookMove> level, List<String> path) {
        Position p = Chess.initial;
        for (final san in path) {
          final m = p.parseSan(san);
          expect(m, isNotNull, reason: '${rep.id} path $path illegal at $san');
          p = p.playUnchecked(m!);
        }
        for (final mv in level) {
          walk(mv.children, [...path, mv.san]);
        }
      }
      walk(book.root, rep.trunk);
    }
  });

  test('dataset has opponent replies after the trunk', () async {
    for (final rep in repertoires) {
      final book = await MasterBook.load(rep.id, trunk: rep.trunk);
      expect(book.movesAt(rep.trunk), isNotEmpty, reason: '${rep.id} has no replies after trunk');
    }
  });

  test('weighted pick only returns dataset moves', () async {
    final rep = repById('london');
    final book = await MasterBook.load(rep.id, trunk: rep.trunk);
    final legal = book.movesAt(rep.trunk).map((m) => m.san).toSet();
    expect(legal, isNotEmpty);
    for (var i = 0; i < 50; i++) {
      final pick = book.pickWeighted(rep.trunk);
      expect(pick, isNotNull);
      expect(legal, contains(pick!.san));
    }
  });
}
