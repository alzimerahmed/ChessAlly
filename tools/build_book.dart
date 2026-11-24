// ignore_for_file: avoid_print
// Build-time book extraction from the Lichess masters opening explorer.
// Usage: dart run tools/build_book.dart [--depth=10] [--min-games=100] [--top=5] [--max-requests=200]
// Writes assets/book/<rep-id>.json for each repertoire trunk.
import 'dart:convert';
import 'dart:io' as io;
import 'package:dartchess/dartchess.dart';

const trunks = {
  'london': ['d4', 'd5', 'Bf4'],
  'caro-kann': ['e4', 'c6', 'd4', 'd5'],
  'french': ['e4', 'e6', 'd4', 'd5'],
};

int depth = 10;
int minGames = 5000; // club games are plentiful — keep only meaningful replies
int topMoves = 6;
int userTop = 2; // user-side replies kept per node
int maxRequests = 250;
const delayMs = 250;
var requestsMade = 0;

// Lichess API token for the games explorer (club-rated games).
// Set via environment: LICHESS_TOKEN=lip_xxx dart run tools/build_book.dart
final token = io.Platform.environment['LICHESS_TOKEN'] ?? '';
const ratings = '1600,1800,2000';
const speeds = 'blitz,rapid,classical';

Future<void> main(List<String> args) async {
  for (final a in args) {
    if (a.startsWith('--depth=')) depth = int.parse(a.split('=')[1]);
    if (a.startsWith('--min-games=')) minGames = int.parse(a.split('=')[1]);
    if (a.startsWith('--top=')) topMoves = int.parse(a.split('=')[1]);
    if (a.startsWith('--max-requests=')) maxRequests = int.parse(a.split('=')[1]);
  }
  final client = io.HttpClient();
  client.connectionTimeout = const Duration(seconds: 30);
  if (token.isEmpty) {
    print('ERROR: set LICHESS_TOKEN env var');
    io.exit(1);
  }

  io.Directory('assets/book').createSync(recursive: true);

  for (final entry in trunks.entries) {
    requestsMade = 0;
    print('=== ${entry.key} ===');
    final root = await expand(client, entry.value, isUserTurn: false, pliesLeft: depth);
    final file = io.File('assets/book/${entry.key}.json');
    file.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(root));
    print('${entry.key}: wrote ${file.lengthSync()} bytes, $requestsMade requests');
  }
  client.close();
  io.exit(0);
}

/// Node shape: {"path": [...], "moves": [{"san","uci","games","white","draws","black","avg","children":[...]}]}
Future<Map<String, dynamic>> expand(io.HttpClient client, List<String> path,
    {required bool isUserTurn, required int pliesLeft}) async {
  final node = <String, dynamic>{'path': path, 'moves': <dynamic>[]};
  if (pliesLeft <= 0 || requestsMade >= maxRequests) return node;

  final moves = await fetchExplorer(client, fenAfter(path));
  if (moves == null) return node;

  final kept = <Map<String, dynamic>>[];
  for (final m in moves) {
    final games = (m['white'] as int) + (m['draws'] as int) + (m['black'] as int);
    if (games < minGames) break; // sorted by games desc
    kept.add({
      'san': m['san'],
      'uci': m['uci'],
      'games': games,
      'white': m['white'],
      'draws': m['draws'],
      'black': m['black'],
      'avg': m['averageRating'],
    });
    if (kept.length >= (isUserTurn ? userTop : topMoves)) break;
  }

  final children = <dynamic>[];
  for (final k in kept) {
    if (pliesLeft <= 1 || requestsMade >= maxRequests) {
      k['children'] = <dynamic>[];
      children.add(k);
      continue;
    }
    final child = await expand(client, [...path, k['san'] as String],
        isUserTurn: !isUserTurn, pliesLeft: pliesLeft - 1);
    k['children'] = child['moves'];
    children.add(k);
  }
  node['moves'] = children;
  return node;
}

Future<List<dynamic>?> fetchExplorer(io.HttpClient client, String fen) async {
  if (requestsMade >= maxRequests) return null;
  requestsMade++;
  final uri = Uri.parse(
      'https://explorer.lichess.ovh/lichess?fen=${Uri.encodeComponent(fen)}&speeds=$speeds&ratings=$ratings&topGames=0&recentGames=0');
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final req = await client.getUrl(uri);
      req.headers.set('Authorization', 'Bearer $token');
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        await Future.delayed(const Duration(milliseconds: delayMs));
        return (jsonDecode(body) as Map<String, dynamic>)['moves'];
      }
      if (res.statusCode == 429) {
        await Future.delayed(const Duration(seconds: 5));
        continue;
      }
      return null;
    } catch (_) {
      await Future.delayed(const Duration(seconds: 2));
    }
  }
  print('  FAILED: $fen');
  return null;
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
