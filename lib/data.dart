// Repertoire data + book-tree logic (ported to Dart).

class TreeNode {
  final String? move;
  final String? name;
  final String? comment;
  final bool key;
  final List<TreeNode> children;
  const TreeNode({this.move, this.name, this.comment, this.key = false, this.children = const []});
}

class OpeningLine {
  final String id, opening, side, name, idea;
  final List<String> moves;
  final Map<int, String> comments;
  const OpeningLine({
    required this.id, required this.opening, required this.side, required this.name,
    required this.moves, required this.idea, this.comments = const {},
  });
}

class Repertoire {
  final String id, name, side, description;
  final List<String> trunk;
  final TreeNode tree;
  final List<OpeningLine> lines;
  const Repertoire({
    required this.id, required this.name, required this.side, required this.description,
    required this.trunk, required this.tree, required this.lines,
  });
}

/// Follow a SAN path; returns node at end, or null if off-book.
TreeNode? followPath(Repertoire rep, List<String> path) {
  if (path.length <= rep.trunk.length) {
    for (var i = 0; i < path.length; i++) {
      if (rep.trunk[i] != path[i]) return null;
    }
    return rep.tree;
  }
  var node = rep.tree;
  for (final san in path.sublist(rep.trunk.length)) {
    TreeNode? next;
    for (final c in node.children) {
      if (c.move == san) {
        next = c;
        break;
      }
    }
    if (next == null) return null;
    node = next;
  }
  return node;
}

List<TreeNode> bookReplies(Repertoire rep, List<String> path) {
  // mid-trunk: the only book reply is the next trunk move
  if (path.length < rep.trunk.length) {
    for (var i = 0; i < path.length; i++) {
      if (rep.trunk[i] != path[i]) return const [];
    }
    return [TreeNode(move: rep.trunk[path.length])];
  }
  return followPath(rep, path)?.children ?? const [];
}

/// Positions in a line where the repertoire side moves -> find-the-move puzzles.
List<({List<String> path, String answer})> puzzlePositions(OpeningLine line, String side) {
  final out = <({List<String> path, String answer})>[];
  for (var i = 0; i < line.moves.length - 1; i++) {
    final moverIsWhite = i % 2 == 0;
    if ((side == 'white') == moverIsWhite) {
      out.add((path: line.moves.sublist(0, i), answer: line.moves[i]));
    }
  }
  return out;
}

final london = Repertoire(
  id: 'london',
  name: 'London System',
  side: 'white',
  trunk: ['d4', 'd5', 'Bf4'],
  description:
      'The London System: solid, low-theory, deadly at club level. Build the pyramid (d4 + Bf4 + e3 + c3 + Nbd2), castle, then strike with e4 or Ne5.',
  tree: const TreeNode(
    children: [
      TreeNode(
        move: 'Nf6',
        name: 'vs 2...Nf6 (main line)',
        comment: 'Most common reply. The classic London setup follows.',
        children: [
          TreeNode(
            move: 'e3',
            key: true,
            comment: 'Support d4, open the f1-bishop already placed on f4.',
            children: [
              TreeNode(
                move: 'e6',
                children: [
                  TreeNode(
                    move: 'Nf3',
                    key: true,
                    children: [
                      TreeNode(
                        move: 'c5',
                        children: [
                          TreeNode(
                            move: 'c3',
                            key: true,
                            comment: 'Bolster d4 before Black gets full counterplay.',
                            children: [
                              TreeNode(
                                move: 'Nc6',
                                children: [
                                  TreeNode(
                                    move: 'Nbd2',
                                    key: true,
                                    comment: 'Pyramid complete: d2 supports the e4 break.',
                                    children: [
                                      TreeNode(
                                        move: 'Bd6',
                                        children: [
                                          TreeNode(
                                            move: 'Bg3',
                                            key: true,
                                            comment:
                                                'Trade dark-squared bishops — a London hallmark. If ...Bxg3, hxg3 opens the h-file.',
                                            children: [
                                              TreeNode(
                                                move: 'O-O',
                                                children: [
                                                  TreeNode(move: 'Qc2', key: true, comment: 'Prepare Ne5 and the e4 break.'),
                                                  TreeNode(
                                                    move: 'Ne5',
                                                    children: [
                                                      TreeNode(move: 'Nxe5', children: [TreeNode(move: 'dxe5', key: true, comment: 'Open the d-file for the rook.')]),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'c5',
        name: 'vs 2...c5',
        comment: 'Benoni-style. Same recipe applies.',
        children: [
          TreeNode(
            move: 'e3',
            key: true,
            children: [
              TreeNode(
                move: 'Nc6',
                children: [
                  TreeNode(
                    move: 'Nf3',
                    key: true,
                    children: [
                      TreeNode(
                        move: 'Nf6',
                        children: [
                          TreeNode(
                            move: 'Nbd2',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'e6',
                                children: [
                                  TreeNode(
                                    move: 'c3',
                                    key: true,
                                    children: [
                                      TreeNode(
                                        move: 'Bd6',
                                        children: [
                                          TreeNode(move: 'Bg3', key: true, comment: 'Trade dark bishops, castle, then Qb3/Ne5 pressure.'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'e6',
        name: 'vs 2...e6',
        children: [
          TreeNode(
            move: 'e3',
            key: true,
            children: [
              TreeNode(
                move: 'c5',
                children: [
                  TreeNode(
                    move: 'c3',
                    key: true,
                    children: [
                      TreeNode(
                        move: 'Nc6',
                        children: [
                          TreeNode(
                            move: 'Nf3',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'Nf6',
                                children: [
                                  TreeNode(
                                    move: 'Bd3',
                                    key: true,
                                    comment: 'With ...e6 played, d3 is the best square for the light bishop.',
                                    children: [
                                      TreeNode(
                                        move: 'Bd6',
                                        children: [
                                          TreeNode(
                                            move: 'Bg3',
                                            key: true,
                                            children: [
                                              TreeNode(move: 'O-O', children: [TreeNode(move: 'Nbd2', key: true)]),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'g6',
        name: 'vs 2...g6 (KID setup)',
        comment: "Black sets up a King's Indian. The London is one of its best antidotes.",
        children: [
          TreeNode(
            move: 'e3',
            key: true,
            children: [
              TreeNode(
                move: 'Bg7',
                children: [
                  TreeNode(
                    move: 'Nf3',
                    key: true,
                    children: [
                      TreeNode(
                        move: 'Nf6',
                        children: [
                          TreeNode(
                            move: 'Nbd2',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'O-O',
                                children: [
                                  TreeNode(
                                    move: 'c3',
                                    key: true,
                                    children: [
                                      TreeNode(
                                        move: 'c5',
                                        children: [
                                          TreeNode(move: 'h4', key: true, comment: 'Against g6 setups, h4-h5 gains space and blunts the g7-bishop.'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'c6',
        name: 'vs 2...c6 (Slav setup)',
        children: [
          TreeNode(
            move: 'e3',
            key: true,
            children: [
              TreeNode(
                move: 'Bf5',
                children: [
                  TreeNode(
                    move: 'Nf3',
                    key: true,
                    children: [
                      TreeNode(
                        move: 'e6',
                        children: [
                          TreeNode(
                            move: 'Nbd2',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'Nf6',
                                children: [
                                  TreeNode(
                                    move: 'Bd3',
                                    key: true,
                                    comment: "Offer the light-bishop trade — removes Black's best piece.",
                                    children: [
                                      TreeNode(
                                        move: 'Bxd3',
                                        children: [
                                          TreeNode(move: 'cxd3', key: true, comment: 'Pawn recovers; 0-0 and Re1 next.'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  lines: const [
    OpeningLine(
      id: 'london-main',
      opening: 'London System',
      side: 'white',
      name: 'Main line vs ...Nf6',
      moves: ['d4', 'd5', 'Bf4', 'Nf6', 'e3', 'e6', 'Nf3', 'c5', 'c3', 'Nc6', 'Nbd2', 'Bd6', 'Bg3', 'O-O', 'Qc2'],
      idea: 'Pyramid setup, trade dark bishops, castle, then break with e4 or Ne5.',
    ),
    OpeningLine(
      id: 'london-c5',
      opening: 'London System',
      side: 'white',
      name: 'vs early ...c5',
      moves: ['d4', 'd5', 'Bf4', 'c5', 'e3', 'Nc6', 'Nf3', 'Nf6', 'Nbd2', 'e6', 'c3', 'Bd6', 'Bg3'],
      idea: 'Same pyramid; c3 keeps the d4 pawn safe before Black expands.',
    ),
    OpeningLine(
      id: 'london-g6',
      opening: 'London System',
      side: 'white',
      name: "vs King's Indian setup",
      moves: ['d4', 'd5', 'Bf4', 'g6', 'e3', 'Bg7', 'Nf3', 'Nf6', 'Nbd2', 'O-O', 'c3', 'c5', 'h4'],
      idea: 'h4-h5 plan blunts the g7 bishop; c3 secures the center.',
    ),
  ],
);

final caroKann = Repertoire(
  id: 'caro-kann',
  name: 'Caro-Kann Defence',
  side: 'black',
  trunk: ['e4', 'c6', 'd4', 'd5'],
  description:
      'The Caro-Kann: rock-solid structure, no weak squares, endgame-friendly. Meet 3.Nc3 with the Classical ...Bf5, 3.e5 with the ...c5 counterstrike, and 3.exd5 with the Panov setup.',
  tree: const TreeNode(
    children: [
      TreeNode(
        move: 'Nc3',
        name: 'Classical Variation',
        comment: 'The main test. Take the e4 pawn and develop with tempo.',
        children: [
          TreeNode(
            move: 'dxe4',
            key: true,
            comment: 'Freeing the c8 bishop — the whole point of ...c6.',
            children: [
              TreeNode(
                move: 'Nxe4',
                children: [
                  TreeNode(
                    move: 'Bf5',
                    key: true,
                    comment: 'The Classical. Develop the bad bishop before it gets locked in.',
                    children: [
                      TreeNode(
                        move: 'Ng3',
                        children: [
                          TreeNode(
                            move: 'Bg6',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'h4',
                                children: [
                                  TreeNode(
                                    move: 'h6',
                                    key: true,
                                    comment: 'Stop h5. If h5 then ...Bh7 keeps the bishop safe.',
                                    children: [
                                      TreeNode(
                                        move: 'Nf3',
                                        children: [
                                          TreeNode(
                                            move: 'Nd7',
                                            key: true,
                                            children: [
                                              TreeNode(
                                                move: 'h5',
                                                children: [
                                                  TreeNode(
                                                    move: 'Bh7',
                                                    key: true,
                                                    children: [
                                                      TreeNode(
                                                        move: 'Bd3',
                                                        children: [
                                                          TreeNode(
                                                            move: 'Bxd3',
                                                            key: true,
                                                            children: [
                                                              TreeNode(
                                                                move: 'Qxd3',
                                                                children: [
                                                                  TreeNode(
                                                                    move: 'e6',
                                                                    key: true,
                                                                    comment: 'Solid. Castle, ...Ngf6 — the structure is bulletproof.',
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'exd5',
        name: 'Exchange Variation / Panov',
        comment: 'White trades in the center. Healthy setup: ...Nf6, ...e6, ...Be7, pressure on d4/c4.',
        children: [
          TreeNode(
            move: 'cxd5',
            key: true,
            children: [
              TreeNode(
                move: 'c4',
                children: [
                  TreeNode(
                    move: 'Nf6',
                    key: true,
                    comment: 'Panov-Botvinnik Attack. Best: ...Nf6, ...e6, ...Be7 and hit d4.',
                    children: [
                      TreeNode(
                        move: 'Nc3',
                        children: [
                          TreeNode(
                            move: 'e6',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'Nf3',
                                children: [
                                  TreeNode(
                                    move: 'Be7',
                                    key: true,
                                    children: [
                                      TreeNode(
                                        move: 'cxd5',
                                        children: [
                                          TreeNode(
                                            move: 'Nxd5',
                                            key: true,
                                            children: [
                                              TreeNode(
                                                move: 'Bd3',
                                                children: [
                                                  TreeNode(move: 'Nc6', key: true, comment: 'Free development; the IQP is not dangerous here.'),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              TreeNode(
                move: 'Bd3',
                children: [
                  TreeNode(move: 'Nc6', key: true, comment: 'Simple and sound: ...Nf6, ...e6, castle.'),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'e5',
        name: 'Advance Variation',
        comment: 'White gains space. The ...c5 counterstrike is the antidote.',
        children: [
          TreeNode(
            move: 'c5',
            key: true,
            comment: 'Hit the base of the chain immediately.',
            children: [
              TreeNode(
                move: 'dxc5',
                children: [
                  TreeNode(
                    move: 'e6',
                    key: true,
                    comment: 'Prepare ...Bxc5 and ...Nc6 with a comfortable game.',
                    children: [
                      TreeNode(
                        move: 'Nf3',
                        children: [
                          TreeNode(
                            move: 'Bxc5',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'Bd3',
                                children: [
                                  TreeNode(
                                    move: 'Nc6',
                                    key: true,
                                    children: [
                                      TreeNode(
                                        move: 'O-O',
                                        children: [
                                          TreeNode(move: 'Nf6', key: true, comment: "Fully developed, no weaknesses. White's e5 pawn is a target."),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'Nf3',
        name: 'Two Knights',
        children: [
          TreeNode(
            move: 'Bg4',
            key: true,
            comment: 'Pin and harass. After h3, take on f3.',
            children: [
              TreeNode(
                move: 'h3',
                children: [
                  TreeNode(
                    move: 'Bxf3',
                    key: true,
                    children: [
                      TreeNode(
                        move: 'Qxf3',
                        children: [
                          TreeNode(
                            move: 'e6',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'Nc3',
                                children: [
                                  TreeNode(
                                    move: 'Nf6',
                                    key: true,
                                    children: [
                                      TreeNode(
                                        move: 'Bd3',
                                        children: [
                                          TreeNode(
                                            move: 'Be7',
                                            key: true,
                                            children: [
                                              TreeNode(move: 'O-O', children: [TreeNode(move: 'O-O', key: true)]),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  lines: const [
    OpeningLine(
      id: 'ck-classical',
      opening: 'Caro-Kann',
      side: 'black',
      name: 'Classical (3.Nc3)',
      moves: ['e4', 'c6', 'd4', 'd5', 'Nc3', 'dxe4', 'Nxe4', 'Bf5', 'Ng3', 'Bg6', 'h4', 'h6', 'Nf3', 'Nd7', 'h5', 'Bh7', 'Bd3', 'Bxd3', 'Qxd3', 'e6'],
      idea: 'Develop the c8 bishop before ...e6. Structure stays perfect.',
    ),
    OpeningLine(
      id: 'ck-panov',
      opening: 'Caro-Kann',
      side: 'black',
      name: 'Panov Attack (3.exd5 c4)',
      moves: ['e4', 'c6', 'd4', 'd5', 'exd5', 'cxd5', 'c4', 'Nf6', 'Nc3', 'e6', 'Nf3', 'Be7', 'cxd5', 'Nxd5', 'Bd3', 'Nc6'],
      idea: 'Accept the IQP with ...Nf6/...e6/...Be7 — not dangerous, gives free development.',
    ),
    OpeningLine(
      id: 'ck-advance',
      opening: 'Caro-Kann',
      side: 'black',
      name: 'Advance (3.e5)',
      moves: ['e4', 'c6', 'd4', 'd5', 'e5', 'c5', 'dxc5', 'e6', 'Nf3', 'Bxc5', 'Bd3', 'Nc6', 'O-O', 'Nf6'],
      idea: '...c5 immediately; the e5 pawn becomes a long-term target.',
    ),
  ],
);

final french = Repertoire(
  id: 'french',
  name: 'French Defence',
  side: 'black',
  trunk: ['e4', 'e6', 'd4', 'd5'],
  description:
      'The French: fight for the light squares and the c-file. Meet 3.Nc3 with the Winawer or Classical, 3.Nd2 with ...dxe4, and the Advance with the ...Qb6 pressure plan.',
  tree: const TreeNode(
    children: [
      TreeNode(
        move: 'Nc3',
        name: 'Main line',
        children: [
          TreeNode(
            move: 'Bb4',
            name: 'Winawer',
            key: true,
            comment: 'The sharpest reply. Pin the knight, wreck the structure.',
            children: [
              TreeNode(
                move: 'e5',
                children: [
                  TreeNode(
                    move: 'c5',
                    key: true,
                    comment: 'Counterattack d4 at once.',
                    children: [
                      TreeNode(
                        move: 'a3',
                        children: [
                          TreeNode(
                            move: 'Bxc3+',
                            key: true,
                            comment: 'Take the knight: doubled c-pawns become targets.',
                            children: [
                              TreeNode(
                                move: 'bxc3',
                                children: [
                                  TreeNode(
                                    move: 'Ne7',
                                    key: true,
                                    children: [
                                      TreeNode(
                                        move: 'Qg4',
                                        children: [
                                          TreeNode(
                                            move: 'Qc7',
                                            key: true,
                                            comment: 'Defend g7 and keep c5 pressure.',
                                            children: [
                                              TreeNode(
                                                move: 'Qxg7',
                                                children: [
                                                  TreeNode(
                                                    move: 'Rg8',
                                                    key: true,
                                                    children: [
                                                      TreeNode(
                                                        move: 'Qxh7',
                                                        children: [
                                                          TreeNode(move: 'cxd4', key: true, comment: 'Smash the center: ...Nbc6, ...dxc3 next. Full compensation.'),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          TreeNode(
            move: 'Nf6',
            name: 'Classical / Steinitz',
            key: true,
            comment: 'The solid alternative to the Winawer.',
            children: [
              TreeNode(
                move: 'e5',
                children: [
                  TreeNode(
                    move: 'Nfd7',
                    key: true,
                    comment: 'Retreat and prepare ...c5.',
                    children: [
                      TreeNode(
                        move: 'f4',
                        children: [
                          TreeNode(
                            move: 'c5',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'Nf3',
                                children: [
                                  TreeNode(
                                    move: 'Nc6',
                                    key: true,
                                    children: [
                                      TreeNode(
                                        move: 'Be3',
                                        children: [
                                          TreeNode(
                                            move: 'cxd4',
                                            key: true,
                                            children: [
                                              TreeNode(
                                                move: 'Nxd4',
                                                children: [
                                                  TreeNode(move: 'Bc5', key: true, comment: 'Hit d4/e3. Black is fully in the game.'),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'Nd2',
        name: 'Tarrasch',
        key: true,
        comment: 'Take the pawn: 3...dxe4 is the modern choice.',
        children: [
          TreeNode(
            move: 'dxe4',
            key: true,
            children: [
              TreeNode(
                move: 'Nxe4',
                children: [
                  TreeNode(
                    move: 'Nd7',
                    key: true,
                    comment: 'Flexible: ...Ngf6 next, trading the strong e4 knight.',
                    children: [
                      TreeNode(
                        move: 'Nf3',
                        children: [
                          TreeNode(
                            move: 'Ngf6',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'Nxf6+',
                                children: [
                                  TreeNode(
                                    move: 'Nxf6',
                                    key: true,
                                    children: [
                                      TreeNode(
                                        move: 'Bd3',
                                        children: [
                                          TreeNode(
                                            move: 'c5',
                                            key: true,
                                            children: [
                                              TreeNode(
                                                move: 'O-O',
                                                children: [
                                                  TreeNode(move: 'cxd4', key: true, comment: 'Healthy structure, easy development.'),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'exd5',
        name: 'Exchange',
        key: true,
        comment: 'Trade back; symmetrical but healthy: ...Nf6, ...Bd6, castle.',
        children: [
          TreeNode(
            move: 'exd5',
            key: true,
            children: [
              TreeNode(
                move: 'Nf3',
                children: [
                  TreeNode(
                    move: 'Nf6',
                    key: true,
                    children: [
                      TreeNode(
                        move: 'Bd3',
                        children: [
                          TreeNode(
                            move: 'Bd6',
                            key: true,
                            children: [
                              TreeNode(
                                move: 'O-O',
                                children: [
                                  TreeNode(move: 'O-O', key: true, comment: 'Equal, solid — nothing to fear.'),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      TreeNode(
        move: 'e5',
        name: 'Advance',
        key: true,
        comment: 'The ...Qb6 plan: hit d4 and b2, force concessions.',
        children: [
          TreeNode(
            move: 'c5',
            key: true,
            children: [
              TreeNode(
                move: 'c3',
                children: [
                  TreeNode(
                    move: 'Nc6',
                    key: true,
                    children: [
                      TreeNode(
                        move: 'Nf3',
                        children: [
                          TreeNode(
                            move: 'Qb6',
                            key: true,
                            comment: 'The signature move: pressure on d4 and b2.',
                            children: [
                              TreeNode(
                                move: 'Be2',
                                children: [
                                  TreeNode(
                                    move: 'cxd4',
                                    key: true,
                                    children: [
                                      TreeNode(
                                        move: 'cxd4',
                                        children: [
                                          TreeNode(move: 'Nh6', key: true, comment: "Head for f5. Black's light-square play is excellent."),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  lines: const [
    OpeningLine(
      id: 'fr-winawer',
      opening: 'French',
      side: 'black',
      name: 'Winawer (3.Nc3 Bb4)',
      moves: ['e4', 'e6', 'd4', 'd5', 'Nc3', 'Bb4', 'e5', 'c5', 'a3', 'Bxc3+', 'bxc3', 'Ne7', 'Qg4', 'Qc7', 'Qxg7', 'Rg8', 'Qxh7', 'cxd4'],
      idea: 'Trade on c3, attack the doubled pawns, use the c-file. Compensation is real.',
    ),
    OpeningLine(
      id: 'fr-classical',
      opening: 'French',
      side: 'black',
      name: 'Classical/Steinitz (3.Nc3 Nf6)',
      moves: ['e4', 'e6', 'd4', 'd5', 'Nc3', 'Nf6', 'e5', 'Nfd7', 'f4', 'c5', 'Nf3', 'Nc6', 'Be3', 'cxd4', 'Nxd4', 'Bc5'],
      idea: 'Solid knight retreat, then ...c5 counterplay.',
    ),
    OpeningLine(
      id: 'fr-tarrasch',
      opening: 'French',
      side: 'black',
      name: 'Tarrasch (3.Nd2)',
      moves: ['e4', 'e6', 'd4', 'd5', 'Nd2', 'dxe4', 'Nxe4', 'Nd7', 'Nf3', 'Ngf6', 'Nxf6+', 'Nxf6', 'Bd3', 'c5', 'O-O', 'cxd4'],
      idea: '...dxe4 then ...Nd7: flexible, trade the e4 knight, healthy structure.',
    ),
    OpeningLine(
      id: 'fr-advance',
      opening: 'French',
      side: 'black',
      name: 'Advance (3.e5)',
      moves: ['e4', 'e6', 'd4', 'd5', 'e5', 'c5', 'c3', 'Nc6', 'Nf3', 'Qb6', 'Be2', 'cxd4', 'cxd4', 'Nh6'],
      idea: '...Qb6 hits d4/b2; reroute the knight to f5.',
    ),
  ],
);

final repertoires = [london, caroKann, french];

Repertoire repById(String id) => repertoires.firstWhere((r) => r.id == id);

/// The curated line that best matches a game history (longest common prefix),
/// or null if the game never reached the repertoire trunk.
String? matchLineId(Repertoire rep, List<String> history) {
  OpeningLine? best;
  var bestLen = 0;
  for (final line in rep.lines) {
    var common = 0;
    while (common < line.moves.length && common < history.length && line.moves[common] == history[common]) {
      common++;
    }
    if (common > bestLen) {
      bestLen = common;
      best = line;
    }
  }
  if (best == null || bestLen < rep.trunk.length) return null;
  return best.id;
}
