# Opening Master — Feature Plan

Goal: make the user a master of exactly two openings — London System (White) and Caro-Kann + French (Black) — faster than any other tool.

## Data sources (all verified working on this machine)

| Source | Use | Status |
|---|---|---|
| Lichess games explorer (`/lichess`) + token | Club-rated move stats (1600–2000), already used for the book bot | ✅ live |
| Lichess masters explorer (`/masters`) | Grandmaster-quality replies for coach suggestions | ✅ live, no auth |
| Lichess puzzle DB (`lichess_db_puzzle.csv.zst`, 310 MB, monthly) | Real puzzles filtered by `OpeningTags` | ✅ downloadable |
| `dartchess` + Stockfish 16 (already bundled) | Legality, engine eval, game review | ✅ in app |
| `shared_preferences` | Local stats/mastery persistence | ✅ in app |

Every feature below can be built 100% offline once the datasets are generated.

---

## P1 — Puzzle system (all puzzle types)

Replace the current "find the book move" mode with a full puzzle engine.

### P1.1 Puzzle dataset pipeline (`tools/build_puzzles.dart`)
- Download `lichess_db_puzzle.csv.zst` once (310 MB) → `cache/puzzles.csv`
- Filter rows where `OpeningTags` contains `London System`, `Caro-Kann`, or `French Defense`
- Bucket by theme: `mate`, `fork`, `pin`, `skewer`, `hangingPiece`, `sacrifice`, `deflection`, `discoveredAttack`, `opening`
- Keep puzzles rated ≤1800 (club-realistic), top ~500 per opening
- Output `assets/puzzles/<rep>.json` — same JSON shape as book: `{fen, solutionMoves[], rating, themes, popularity}`

### P1.2 Puzzle types in-app
| Type | Source |
|---|---|
| **Opening setup** | Existing book-move puzzles (already built) — rename "Book drills" |
| **Middlegame tactics** | Filtered puzzle DB (fork/pin/skewer/deflection) |
| **Checkmate patterns** | Filtered puzzle DB (mate1/mate2/mate3+ themes) |
| **Sacrifices & attacks** | Filtered puzzle DB (sacrifice, attraction, clearance) |
| **Defense** | Filtered puzzles where the correct side is your repertoire side |

### P1.3 Puzzle UX (chess.com-style)
- Rating ladder: user puzzle rating starts 800, ±Elo-adjusted per solve
- Themes filter chips (mate, fork, pin…)
- "Retry wrong" queue — failed puzzles resurface
- Daily puzzle (deterministic by date seed)
- Streak tracking (already in stats)

---

## P2 — Coach: theory walkthrough for every line

### P2.1 Auto-generated walkthroughs (`tools/build_theory.dart`)
- Walk `assets/book/*.json` top-to-bottom
- For each node, emit: SAN, FEN, ECO name (from explorer), games, win%, the top-3 continuations with stats
- Attach a curated comment layer: hand-written explanations for the ~30 most important positions per opening (stored in `lib/data.dart` already — keep extending it)
- Output `assets/theory/<rep>.json`

### P2.2 Theory screen v2
- Browse the full book tree (not just 3 curated lines): expandable variation tree sidebar
- Per-node panel: win/draw/loss percentages, "most common at your rating" badge, ECO name
- "Quiz me on this line" — hides the next move, you must find it (uses puzzlePositions logic)
- "Weak spots" view: lines where your puzzle stats show mistakes

---

## P3 — Bots: levels + opening challenges

### P3.1 Difficulty levels
| Level | Engine | Book behavior |
|---|---|---|
| Beginner | depth 2 | plays most popular reply |
| Casual | depth 6 | frequency-weighted (current) |
| Club | depth 10 | frequency-weighted |
| Sharp | depth 12 | picks **low-frequency** book moves to test edge cases |
| Master | depth 14 | picks **highest-scoring** book moves (engine + win%) |

Implement as a `BotProfile` enum passed to `aiMoveBook`.

### P3.2 Challenge modes
- **Variation gauntlet**: bot is locked to one line (e.g. "only Advance Caro-Kann") — master each branch in isolation
- **Survival**: must survive 15+ plies on-book without a mistake to pass the line
- **Speed**: 3|0 blitz clock vs book bot
- **Custom opponent**: pick which opponent reply tree the bot must follow

---

## P4 — Game review (chess.com-style analysis)

### P4.1 Engine (`lib/analysis.dart`)
After a game ends, evaluate every move:
- `evalPosition(fen_before)` → cp before
- `evalPosition(fen_after)` → cp after
- `bestMove` per position

### P4.2 Move classification (chess.com thresholds)
| Tag | Centipawn loss |
|---|---|
| Best | ≤0 cp |
| Excellent | ≤25 cp |
| Good | ≤50 cp |
| Inaccuracy | ≤100 cp |
| Mistake | ≤300 cp |
| Blunder | >300 cp |
| Book | move is in your repertoire dataset |
| Miss | best move won material/mate and yours didn't |

### P4.3 Review UI
- Accuracy % (chess.com formula: avg move quality)
- Move list with color-coded tags
- "Key moments" — top 3 biggest swings
- Blunder replay button (jump to position)
- Store per-game accuracy in stats → drives mastery %

---

## P5 — Mastery & stats v2
- Per-line mastery = f(theory studied %, puzzle accuracy on that line, review accuracy in games where that line occurred)
- Daily streak, weekly goals, XP levels
- "Opening strength" estimate: accuracy on-book vs off-book

---

## P6 — PGN & export
- PGN export button (already have SAN history — serialize with headers)
- Import PGN → walk it in analysis mode

---

## Build order

1. **P4 game review** — highest training value, all pieces exist (engine + history)
2. **P1 puzzle pipeline** — one download, then real opening-specific tactics forever
3. **P3 bot profiles** — small code change on top of existing book bot
4. **P2 theory v2** — auto-generates most content; curation layer optional
5. **P5 mastery v2** — polish last

## Done so far
- Book bot from real club data (750 positions/opening, frequency-weighted)
- Curated tree + comment layer for all 3 openings
- Game modes scaffold: Play / Coach / Puzzles / Theory / Analysis / Profile
- Strength levels, clocks, move list, stats, streaks, line mastery
- 12 tests green; Stockfish engine verified working
