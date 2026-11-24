/// Minimal PGN serialization/parsing for game export and import.
library;

/// Serialize a SAN move list to PGN with headers.
String toPgn(List<String> sanHistory, {Map<String, String> headers = const {}, String result = '*'}) {
  final buf = StringBuffer();
  for (final e in headers.entries) {
    buf.writeln('[${e.key} "${e.value}"]');
  }
  if (headers.isNotEmpty) buf.writeln();
  final tokens = <String>[];
  for (var i = 0; i < sanHistory.length; i++) {
    if (i.isEven) tokens.add('${i ~/ 2 + 1}.');
    tokens.add(sanHistory[i]);
  }
  tokens.add(result);
  buf.write(tokens.join(' '));
  return buf.toString();
}

/// Parse a PGN string to a SAN move list. Strips headers, comments,
/// variations, NAGs, move numbers and result tokens. Throws FormatException
/// with a move index if a SAN token is not parseable later in the replay.
List<String> parsePgn(String pgn) {
  var text = pgn;
  text = text.replaceAll(RegExp(r'\[\w+\s+"[^"]*"\]'), ' '); // headers
  text = text.replaceAll(RegExp(r';[^\n]*'), ' '); // rest-of-line comments
  text = text.replaceAll(RegExp(r'\{[^}]*\}'), ' '); // brace comments
  while (text.contains('(')) {
    // strip innermost variations first
    final inner = RegExp(r'\([^()]*\)').firstMatch(text);
    if (inner == null) break;
    text = text.replaceRange(inner.start, inner.end, ' ');
  }
  text = text.replaceAll(RegExp(r'\$\d+'), ' '); // NAGs

  final sans = <String>[];
  for (final token in text.split(RegExp(r'\s+'))) {
    if (token.isEmpty) continue;
    if (token == '*' || RegExp(r'^(1-0|0-1|1/2-1/2)$').hasMatch(token)) continue;
    final san = token.replaceFirst(RegExp(r'^\d+\.+'), '');
    if (san.isEmpty || san == '...') continue;
    sans.add(san);
  }
  return sans;
}
