// ignore_for_file: avoid_print
// Build-time theory walkthrough generation from the masters book datasets.
// Usage: dart run tools/build_theory.dart
// Writes assets/theory/<rep-id>.json for each repertoire.
//
// For every node in assets/book/<rep>.json it emits: full SAN path, FEN,
// games, win/draw/loss percentages, the top-3 continuations with stats, and
// a curated comment/name layer matched from lib/data.dart repertoire lines.
import 'dart:convert';
import 'dart:io' as io;
import 'package:dartchess/dartchess.dart';
import 'package:opening_master/data.dart';

const trunks = {
  'london': ['d4', 'd5', 'Bf4'],
  'caro-kann': ['e4', 'c6', 'd4', 'd5'],
  'french': ['e4', 'e6', 'd4', 'd5'],
};

void main() {
  io.Directory('assets/theory').createSync(recursive: true);

  for (final entry in trunks.entries) {
    final repId = entry.key;
    final rep = repById(repId);
    final raw = io.File('assets/book/$repId.json').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final root = data['moves'] as List;

    final nodes = <Map<String, dynamic>>[];
    walk(root, entry.value, rep, nodes);

    final file = io.File('assets/theory/$repId.json');
    file.writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
      'rep': repId,
      'trunk': entry.value,
      'nodes': nodes,
    }));
    print('$repId: ${nodes.length} nodes -> ${file.path} (${file.lengthSync()} bytes)');
  }
}

void walk(List<dynamic> moves, List<String> path, Repertoire rep, List<Map<String, dynamic>> out) {
  for (final m in moves) {
    final san = m['san'] as String;
    final childPath = [...path, san];
    final games = m['games'] as int;
    final white = m['white'] as int;
    final draws = m['draws'] as int;
    final black = m['black'] as int;

    // top-3 continuations by games
    final children = (m['children'] as List? ?? []).toList();
    children.sort((a, b) => (b['games'] as int).compareTo(a['games'] as int));
    final top = children.take(3).map((c) => {
          'san': c['san'],
          'games': c['games'],
          'white': c['white'],
          'draws': c['draws'],
          'black': c['black'],
        }).toList();

    // curated comment layer: first line whose moves extend this path
    String? comment;
    String? name;
    for (final line in rep.lines) {
      if (line.moves.length >= childPath.length &&
          _matchesPrefix(line.moves, childPath)) {
        name ??= line.name;
        comment ??= line.comments[childPath.length - 1];
      }
      if (comment != null && name != null) break;
    }

    out.add({
      'path': childPath,
      'fen': fenAfter(childPath),
      'games': games,
      'white': white,
      'draws': draws,
      'black': black,
      'name': ?name,
      'comment': ?comment,      'top': top,
    });

    if (children.isNotEmpty) {
      walk(children, childPath, rep, out);
    }
  }
}

bool _matchesPrefix(List<String> lineMoves, List<String> path) {
  for (var i = 0; i < path.length; i++) {
    if (lineMoves[i] != path[i]) return false;
  }
  return true;
}

String fenAfter(List<String> sans) {
  Position p = Chess.initial;
  for (final san in sans) {
    final m = p.parseSan(san);
    if (m == null) throw StateError('illegal $san in $sans');
    p = p.playUnchecked(m);
  }
  return p.fen;
}
