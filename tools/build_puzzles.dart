// ignore_for_file: avoid_print
// Build-time puzzle extraction from the Lichess puzzle database.
// Usage: dart run tools/build_puzzles.dart [--max-per-rep=500] [--max-rating=1800]
// Writes assets/puzzles/<rep-id>.json for each repertoire.
//
// Pipeline:
//   1. download https://database.lichess.org/lichess_db_puzzle.csv.zst -> cache/
//   2. decompress via python zstandard (no zstd CLI on this machine)
//   3. stream-filter rows whose OpeningTags match a repertoire opening
//   4. keep rating <= max-rating, top N per rep by popularity
import 'dart:convert';
import 'dart:io' as io;

const zstUrl = 'https://database.lichess.org/lichess_db_puzzle.csv.zst';
const zstPath = 'cache/lichess_db_puzzle.csv.zst';
const csvPath = 'cache/puzzles.csv';

// OpeningTags in the DB use spaces (e.g. "French Defense, French Defense: Classical").
// Match case-insensitively on the opening family prefix.
const repTags = {
  'london': 'London System',
  'caro-kann': 'Caro-Kann',
  'french': 'French Defense',
};

int maxPerRep = 500;
int maxRating = 1800;

Future<void> main(List<String> args) async {
  for (final a in args) {
    if (a.startsWith('--max-per-rep=')) maxPerRep = int.parse(a.split('=')[1]);
    if (a.startsWith('--max-rating=')) maxRating = int.parse(a.split('=')[1]);
  }

  io.Directory('cache').createSync(recursive: true);
  io.Directory('assets/puzzles').createSync(recursive: true);

  if (!io.File(csvPath).existsSync()) {
    if (!io.File(zstPath).existsSync()) {
      print('Downloading puzzle DB (~310 MB)…');
      await download(zstUrl, zstPath);
    }
    print('Decompressing…');
    await decompress(zstPath, csvPath);
  }

  // rep -> list of candidate rows
  final candidates = <String, List<Map<String, dynamic>>>{for (final k in repTags.keys) k: []};
  var scanned = 0, matched = 0;

  final stream = io.File(csvPath).openRead().transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in stream) {
    scanned++;
    if (scanned % 500000 == 0) print('  scanned $scanned, matched $matched');
    if (line.isEmpty || line.startsWith('PuzzleId')) continue;
    final cols = splitCsv(line);
    // PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags
    if (cols.length < 10) continue;
    final tags = cols[9].toLowerCase().replaceAll('_', ' ');
    String? rep;
    for (final e in repTags.entries) {
      if (tags.contains(e.value.toLowerCase())) {
        rep = e.key;
        break;
      }
    }
    if (rep == null) continue;
    final rating = int.tryParse(cols[3]);
    if (rating == null || rating > maxRating) continue;
    final popularity = int.tryParse(cols[5]) ?? 0;
    candidates[rep]!.add({
      'id': cols[0],
      'fen': cols[1],
      'solutionMoves': cols[2].split(' '),
      'rating': rating,
      'themes': cols[7].split(' ').where((t) => t.isNotEmpty).toList(),
      'popularity': popularity,
      'openingTags': cols[9].split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
    });
    matched++;
  }

  for (final e in candidates.entries) {
    e.value.sort((a, b) => (b['popularity'] as int).compareTo(a['popularity'] as int));
    final kept = e.value.take(maxPerRep).toList();
    final file = io.File('assets/puzzles/${e.key}.json');
    file.writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
      'puzzles': kept,
    }));
    print('${e.key}: kept ${kept.length} of ${e.value.length} -> ${file.path} (${file.lengthSync()} bytes)');
  }
  print('done: scanned $scanned lines, matched $matched');
  io.exit(0);
}

/// Minimal CSV split (no quoted commas in this dataset, but be safe).
List<String> splitCsv(String line) {
  final out = <String>[];
  var cur = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      inQuotes = !inQuotes;
    } else if (c == ',' && !inQuotes) {
      out.add(cur.toString());
      cur = StringBuffer();
    } else {
      cur.write(c);
    }
  }
  out.add(cur.toString());
  return out;
}

Future<void> download(String url, String to) async {
  final client = io.HttpClient();
  client.connectionTimeout = const Duration(seconds: 60);
  final req = await client.getUrl(Uri.parse(url));
  final res = await req.close();
  if (res.statusCode != 200) {
    print('ERROR: download failed (${res.statusCode})');
    io.exit(1);
  }
  final sink = io.File(to).openWrite();
  await res.pipe(sink);
  client.close();
  print('downloaded -> $to (${io.File(to).lengthSync()} bytes)');
}

Future<void> decompress(String zst, String to) async {
  final result = await io.Process.run('python', [
    '-c',
    "import zstandard, shutil\n"
        "with open(r'$zst', 'rb') as f, open(r'$to', 'wb') as o:\n"
        "    dctx = zstandard.ZstdDecompressor().stream_reader(f)\n"
        "    shutil.copyfileobj(dctx, o)\n",
  ]);
  if (result.exitCode != 0) {
    print('ERROR: decompression failed:\n${result.stdout}\n${result.stderr}');
    io.exit(1);
  }
  print('decompressed -> $to');
}
