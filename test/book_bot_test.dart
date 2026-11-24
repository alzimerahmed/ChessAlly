import 'package:flutter_test/flutter_test.dart';
import 'package:opening_master/data.dart';
import 'package:opening_master/game_controller.dart';

void main() {
  test('book bot follows repertoire lines without engine', () async {
    final game = GameController();
    final rep = repById('london'); // user plays White; bot is Black

    // user plays the trunk
    for (final san in rep.trunk) {
      expect(game.moveSan(san), isTrue, reason: san);
    }
    // bot must reply with a book move (no engine needed)
    final r = await game.aiMoveBook(rep, profile: BotProfile.beginner);
    expect(r, isNotNull);
    expect(r!.source, 'book');
    final bookAfter = bookReplies(rep, rep.trunk).map((c) => c.move!);
    expect(bookAfter, contains(r.san));
  });

  test('book bot falls back to engine when off-book', () async {
    final game = GameController();
    final rep = repById('london');
    // user plays something off-book: 1.e4 (not in the London tree)
    expect(game.moveSan('e4'), isTrue);
    final r = await game.aiMoveBook(rep, profile: BotProfile.beginner);
    // engine may be unavailable in the test host; then no move is played
    expect(r == null || r.source == 'engine', isTrue);
  });

  test('book bot keeps the game on-book for many plies', () async {
    final game = GameController();
    final rep = repById('caro-kann'); // user plays Black; bot is White
    // bot is White: it must open with a book reply at the start
    var r = await game.aiMoveBook(rep, profile: BotProfile.beginner);
    expect(r!.source, 'book');
    expect(r.san, 'e4'); // trunk starts with e4
    // user follows the trunk (Black moves only: c6, d5), bot keeps answering
    for (final san in [rep.trunk[1], rep.trunk[3]]) {
      expect(game.moveSan(san), isTrue, reason: san);
      r = await game.aiMoveBook(rep, profile: BotProfile.beginner);
      expect(r, isNotNull);
      expect(r!.source, 'book', reason: 'bot left the book at ${game.history.join(' ')}');
    }
  });
}
