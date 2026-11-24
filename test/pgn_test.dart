import 'package:flutter_test/flutter_test.dart';
import 'package:opening_master/pgn.dart';

void main() {
  group('toPgn', () {
    test('numbers the moves and appends the result', () {
      expect(toPgn(['e4', 'e5', 'Nf3']), '1. e4 e5 2. Nf3 *');
    });
    test('writes headers and a blank line', () {
      final pgn = toPgn(['e4'], headers: {'Event': 'Test', 'Result': '1-0'}, result: '1-0');
      expect(pgn, contains('[Event "Test"]'));
      expect(pgn, contains('[Result "1-0"]'));
      expect(pgn, endsWith('1. e4 1-0'));
      expect(pgn, contains('\n\n'));
    });
    test('empty history still emits the result', () {
      expect(toPgn(const []), '*');
    });
  });

  group('parsePgn', () {
    test('plain movetext', () {
      expect(parsePgn('1. e4 e5 2. Nf3 Nc6 3. Bb5 *'), ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
    });
    test('strips headers, comments, variations, NAGs', () {
      const pgn = '''
[Event "Test"]
[Result "1-0"]

1. e4 {best by far} e5 (1... c5 2. Nf3) 2. Nf3 \$1 Nc6 1-0
; a line comment
''';
      expect(parsePgn(pgn), ['e4', 'e5', 'Nf3', 'Nc6']);
    });
    test('glued move numbers', () {
      expect(parsePgn('1.e4 e5 2.Nf3'), ['e4', 'e5', 'Nf3']);
    });
    test('black-to-start movetext with ellipsis numbers', () {
      expect(parsePgn('1. e4 e5 2... Nf3'), ['e4', 'e5', 'Nf3']);
    });
    test('nested variations', () {
      expect(parsePgn('1. e4 (1. d4 (1. c4) d5) e5'), ['e4', 'e5']);
    });
    test('round trip', () {
      const sans = ['e4', 'c6', 'd4', 'd5', 'Nc3', 'dxe4', 'Nxe4'];
      expect(parsePgn(toPgn(sans, result: '1-0')), sans);
    });
  });
}
