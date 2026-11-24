import 'package:flutter/material.dart';
import '../data.dart';
import '../stats.dart';

class ProfileScreen extends StatelessWidget {
  final Stats stats;
  const ProfileScreen({super.key, required this.stats});

  static const _weakThreshold = 75.0;

  Widget row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(k)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]),
      );

  Widget progress(String label, double value0to1, String caption) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(label)),
            Text(caption, style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
          LinearProgressIndicator(value: value0to1.clamp(0.0, 1.0)),
        ]),
      );

  String _pct(double? v) => v == null ? '—' : '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final acc = s.puzzlesAttempted > 0 ? (s.puzzlesCorrect / s.puzzlesAttempted * 100).round() : 0;
    final strength = s.openingStrength;

    // weak spots: lines with review accuracy below threshold, worst first
    final weakSpots = <(String, String, double)>[];
    for (final rep in repertoires) {
      for (final line in rep.lines) {
        final acc2 = s.reviewAccuracyForLine(line.id);
        if (acc2 != null && acc2 < _weakThreshold) {
          weakSpots.add(('${rep.name} — ${line.name}', line.id, acc2));
        }
      }
    }
    weakSpots.sort((a, b) => a.$3.compareTo(b.$3));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(children: [
        Text('Your path to opening mastery', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Level ${s.level} · ${s.xp} XP', style: Theme.of(context).textTheme.titleMedium),
        LinearProgressIndicator(value: s.levelProgress),
        Text('${500 - s.xp % 500} XP to level ${s.level + 1}',
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        const SizedBox(height: 16),
        row('Games played', '${s.games}'),
        row('Record (W/L/D)', '${s.wins} / ${s.losses} / ${s.draws}'),
        row('Puzzle accuracy', '$acc% (${s.puzzlesCorrect}/${s.puzzlesAttempted})'),
        row('Puzzle rating', '${s.puzzleRating}'),
        row('Puzzle streak', '${s.puzzleStreak} (best ${s.puzzleBestStreak})'),
        row('Avg review accuracy', _pct(s.reviewGames > 0 ? s.avgReviewAccuracy : null)),
        row('Daily streak', '${s.dailyStreak} days'),
        const SizedBox(height: 16),
        Text('Weekly goals', style: Theme.of(context).textTheme.titleMedium),
        progress('Games', s.weekGames / weeklyGameGoal, '${s.weekGames}/$weeklyGameGoal'),
        progress('Puzzles', s.weekPuzzles / weeklyPuzzleGoal, '${s.weekPuzzles}/$weeklyPuzzleGoal'),
        const SizedBox(height: 16),
        Text('Opening strength', style: Theme.of(context).textTheme.titleMedium),
        if (strength != null) ...[
          row('Accuracy on-book', _pct(strength.book)),
          row('Accuracy off-book', _pct(strength.offBook)),
          row('Opening edge', '+${strength.edge.toStringAsFixed(1)}%'),
          Text(
            strength.edge >= 15
                ? 'Your repertoire is paying off — you play much stronger in known lines.'
                : strength.edge >= 5
                    ? 'Solid edge in your openings. Keep drilling the weak lines below.'
                    : 'Little edge so far — study theory and drill book puzzles.',
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ] else
          const Text('Play and review a few games to estimate your opening strength.'),
        const SizedBox(height: 16),
        Text('Line mastery', style: Theme.of(context).textTheme.titleMedium),
        Text('theory 40% · review accuracy 40% · puzzle accuracy 20%',
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
        for (final rep in repertoires)
          for (final line in rep.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${rep.name} — ${line.name}'),
                Row(children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (s.lineMasteryV2(line.id, rep.id) / 100).clamp(0.0, 1.0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${s.lineMasteryV2(line.id, rep.id).toStringAsFixed(0)}%'),
                ]),
              ]),
            ),
        if (weakSpots.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Weak spots', style: Theme.of(context).textTheme.titleMedium),
          for (final (name, _, acc3) in weakSpots)
            row(name, '${acc3.toStringAsFixed(1)}%'),
        ],
      ]),
    );
  }
}
