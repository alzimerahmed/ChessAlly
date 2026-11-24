import 'dart:convert';
import 'dart:math' show pow;
import 'package:flutter/services.dart' show rootBundle;
import 'package:dartchess/dartchess.dart';

/// One puzzle from the Lichess puzzle DB, filtered to a repertoire opening.
class Puzzle {
  final String id, fen;
  final List<String> solutionMoves; // UCI, alternating solver/opponent
  final int rating, popularity;
  final List<String> themes, openingTags;
  const Puzzle({
    required this.id,
    required this.fen,
    required this.solutionMoves,
    required this.rating,
    required this.popularity,
    required this.themes,
    required this.openingTags,
  });

  factory Puzzle.fromJson(dynamic j) => Puzzle(
        id: j['id'],
        fen: j['fen'],
        solutionMoves: List<String>.from(j['solutionMoves']),
        rating: j['rating'],
        popularity: j['popularity'] ?? 0,
        themes: List<String>.from(j['themes'] ?? const []),
        openingTags: List<String>.from(j['openingTags'] ?? const []),
      );

  /// Side that solves this puzzle. Lichess convention: the FEN has the
  /// opponent to move; they play solutionMoves[0], the solver plays [1] onward.
  /// (Single-move fallback: the FEN side to move.)
  Side get solverSide {
    final turn = Chess.fromSetup(Setup.parseFen(fen)).turn;
    return solutionMoves.length > 1 ? turn.opposite : turn;
  }
}

/// The filtered puzzle set for one repertoire (`assets/puzzles/<rep>.json`).
class PuzzleSet {
  final String repId;
  final List<Puzzle> puzzles;
  const PuzzleSet(this.repId, this.puzzles);

  static final Map<String, PuzzleSet> _cache = {};

  static Future<PuzzleSet> load(String repId) async {
    final cached = _cache[repId];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/puzzles/$repId.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final set = PuzzleSet(
      repId,
      (data['puzzles'] as List? ?? []).map(Puzzle.fromJson).toList(),
    );
    _cache[repId] = set;
    return set;
  }

  /// Themes present in this set, by frequency (for filter chips).
  List<String> get themes {
    final counts = <String, int>{};
    for (final p in puzzles) {
      for (final t in p.themes) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  /// Deterministic daily puzzle: same puzzle all day, per rep.
  Puzzle? daily() {
    if (puzzles.isEmpty) return null;
    final seed = DateTime.now(); // same day -> same puzzle
    final dayNumber = seed.year * 10000 + seed.month * 100 + seed.day;
    final idx = (dayNumber * 2654435761 % puzzles.length).abs();
    return puzzles[idx];
  }
}

/// Elo update after one attempt at a puzzle of [puzzleRating].
int updatePuzzleRating(int userRating, int puzzleRating, bool solved) {
  final expected = 1 / (1 + pow(10, (puzzleRating - userRating) / 400));
  return (userRating + 32 * ((solved ? 1.0 : 0.0) - expected)).round();
}
