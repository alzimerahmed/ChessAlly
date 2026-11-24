import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dartchess/dartchess.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opening_master/board.dart';
import 'package:opening_master/data.dart';
import 'package:opening_master/puzzles.dart';
import 'package:opening_master/screens/puzzles.dart';
import 'package:opening_master/screens/theory.dart';
import 'package:opening_master/screens/profile.dart';
import 'package:opening_master/stats.dart';
import 'package:opening_master/theory.dart';

/// Give the test a tall surface so ListViews don't clip the board/sections.
Future<void> bigSurface(WidgetTester tester, {double height = 1400}) async {
  await tester.binding.setSurfaceSize(Size(800, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Tap a board square by computing its position inside the ChessBoard widget.
Future<void> tapSquare(WidgetTester tester, Square sq, {bool whiteBottom = true}) async {
  await tester.ensureVisible(find.byType(ChessBoard));
  await tester.pump();
  final boardRect = tester.getRect(find.byType(ChessBoard));
  final cell = boardRect.width / 8;
  final col = whiteBottom ? sq.file : 7 - sq.file;
  final row = whiteBottom ? 7 - sq.rank : sq.rank;
  final offset = boardRect.topLeft + Offset((col + 0.5) * cell, (row + 0.5) * cell);
  await tester.tapAt(offset);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  // Asset I/O cannot complete inside testWidgets' fake-async zone; preload
  // the cached datasets here (plain async, real I/O) so in-test loads are
  // instant cache hits.
  setUpAll(() async {
    await PuzzleSet.load('london');
    await TheorySet.load('london');
  });

  testWidgets('tactics puzzle: full solve flow updates stats and rating', (tester) async {
    final stats = Stats();
    var statsUpdated = 0;
    final set = await PuzzleSet.load('london');
    expect(set.puzzles, isNotEmpty);
    final expected = set.puzzles.first; // theme filter null -> first puzzle

    await bigSurface(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PuzzlesScreen(stats: stats, setStats: (_) => statsUpdated++),
      ),
    ));
    await tester.pumpAndSettle();

    // switch to Tactics
    await tester.tap(find.text('Tactics'));
    await tester.pumpAndSettle();

    // puzzle loaded: rating ladder and board visible
    expect(find.textContaining('Puzzle rating:'), findsOneWidget);
    expect(find.byType(ChessBoard), findsOneWidget);

    // Lichess convention: move 0 is the opponent's (auto-played); the solver
    // plays the odd-indexed moves.
    var whiteBottom = expected.solverSide == Side.white;
    for (var i = 1; i < expected.solutionMoves.length; i += 2) {
      final uci = expected.solutionMoves[i];
      final from = Square.fromName(uci.substring(0, 2));
      final to = Square.fromName(uci.substring(2, 4));
      await tapSquare(tester, from, whiteBottom: whiteBottom);
      await tapSquare(tester, to, whiteBottom: whiteBottom);
      // opponent reply is auto-played after 500ms
      if (i + 1 < expected.solutionMoves.length) {
        await tester.pump(const Duration(milliseconds: 600));
      }
    }
    expect(find.textContaining('✅ Solved!'), findsOneWidget);
    expect(stats.puzzlesAttempted, 1);
    expect(stats.puzzlesCorrect, 1);
    expect(statsUpdated, greaterThan(0));
    // Elo moved up for solving a puzzle
    expect(stats.puzzleRating, greaterThan(800));
    // flush the auto-advance timer so no timers are pending at teardown
    await tester.pump(const Duration(milliseconds: 1000));
  });

  testWidgets('tactics puzzle: wrong move flags failure once and queues retry', (tester) async {
    final stats = Stats();
    final set = await PuzzleSet.load('london');
    final expected = set.puzzles.first;

    await bigSurface(tester);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PuzzlesScreen(stats: stats, setStats: (_) {})),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tactics'));
    await tester.pumpAndSettle();

    // find a legal move that is NOT the solver's solution move: the board
    // already shows the position after the auto-played opponent move
    final pos = Chess.fromSetup(Setup.parseFen(expected.fen));
    final oppMove = NormalMove.fromUci(expected.solutionMoves.first);
    final solverPos = pos.playUnchecked(oppMove);
    final solverUci = expected.solutionMoves[1];
    String? wrongUci;
    for (final entry in solverPos.legalMoves.entries) {
      for (final to in entry.value.squares) {
        final uci = '${entry.key.name}${to.name}';
        if (uci != solverUci && uci.length == 4) {
          wrongUci = uci;
          break;
        }
      }
      if (wrongUci != null) break;
    }
    if (wrongUci != null) {
      final whiteBottom = expected.solverSide == Side.white;
      await tapSquare(tester, Square.fromName(wrongUci.substring(0, 2)), whiteBottom: whiteBottom);
      await tapSquare(tester, Square.fromName(wrongUci.substring(2, 4)), whiteBottom: whiteBottom);
      expect(find.textContaining('❌'), findsOneWidget);
      expect(stats.puzzlesAttempted, 1);
      expect(stats.puzzlesCorrect, 0);
      expect(stats.puzzleRetryQueue, contains('london|${expected.id}'));
      expect(stats.puzzleRating, lessThan(800));
    }
  });

  testWidgets('theory screen: tree browser renders and selects nodes', (tester) async {
    final stats = Stats();
    await bigSurface(tester, height: 2200);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TheoryScreen(stats: stats, setStats: (_) {})),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tree'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Variation tree ('), findsOneWidget);
    // first tree row is visible with games count
    expect(find.textContaining('games ·'), findsWidgets);

    // tap the first row -> node panel with W/D/L appears
    final row = find.textContaining('games ·').first;
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await tester.pump();
    expect(find.textContaining('W '), findsWidgets);
  });

  testWidgets('theory screen: quiz mode starts and accepts a book move', (tester) async {
    final stats = Stats();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: TheoryScreen(stats: stats, setStats: (_) {})),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz me on this opening'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Find a book move'), findsOneWidget);
    expect(find.byType(ChessBoard), findsOneWidget);
  });

  testWidgets('profile screen renders all v2 sections', (tester) async {
    final lineId = repById('london').lines.first.id;
    final stats = Stats()
      ..games = 3
      ..wins = 2
      ..puzzlesAttempted = 10
      ..puzzlesCorrect = 8
      ..puzzleRating = 950
      ..reviewGames = 2
      ..reviewAccSum = 160
      ..lineMastery[lineId] = 40
      ..reviewLineSum[lineId] = 70
      ..reviewLineCount[lineId] = 1
      ..reviewBookSum = 170
      ..reviewBookCount = 2
      ..reviewOffBookSum = 130
      ..reviewOffBookCount = 2
      ..puzzleAttemptedByRep['london'] = 10
      ..puzzleCorrectByRep['london'] = 8;

    await bigSurface(tester, height: 2400);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ProfileScreen(stats: stats)),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Level '), findsOneWidget);
    expect(find.text('Weekly goals'), findsOneWidget);
    expect(find.text('Opening strength'), findsOneWidget);
    expect(find.textContaining('Accuracy on-book'), findsOneWidget);
    expect(find.textContaining('Opening edge'), findsOneWidget);
    expect(find.text('Line mastery'), findsOneWidget);
    // mastery v2 blends: theory 40*0.4 + review 70*0.4 + puzzle 80*0.2 = 60
    expect(find.text('60%'), findsWidgets);
  });
}
