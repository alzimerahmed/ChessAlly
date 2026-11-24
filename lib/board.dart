import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

const _glyphs = {
  'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚',
  'P': '♙', 'N': '♘', 'B': '♗', 'R': '♖', 'Q': '♕', 'K': '♔',
};

/// A simple, functional chessboard: tap to select, tap target to move.
class ChessBoard extends StatelessWidget {
  final Position position;
  final bool whiteOnBottom;
  final void Function(Move move, String san)? onMove;
  final List<Square> highlight; // e.g. best move hint
  final List<Square> lastMove; // [from, to]
  final bool interactive;

  const ChessBoard({
    super.key,
    required this.position,
    this.whiteOnBottom = true,
    this.onMove,
    this.highlight = const [],
    this.lastMove = const [],
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: _BoardGrid(
        position: position,
        whiteOnBottom: whiteOnBottom,
        onMove: onMove,
        highlight: highlight,
        lastMove: lastMove,
        interactive: interactive,
      ),
    );
  }
}

class _BoardGrid extends StatefulWidget {
  final Position position;
  final bool whiteOnBottom;
  final void Function(Move, String)? onMove;
  final List<Square> highlight;
  final List<Square> lastMove;
  final bool interactive;
  const _BoardGrid({
    required this.position,
    required this.whiteOnBottom,
    this.onMove,
    required this.highlight,
    required this.lastMove,
    required this.interactive,
  });

  @override
  State<_BoardGrid> createState() => _BoardGridState();
}

class _BoardGridState extends State<_BoardGrid> {
  Square? _selected;

  Set<Square> get _targets {
    if (_selected == null) return {};
    return widget.position.legalMoves[_selected!]?.squares.toSet() ?? {};
  }

  void _tap(Square sq) {
    if (!widget.interactive || widget.onMove == null) return;
    if (_selected != null) {
      final targets = _targets;
      if (targets.contains(sq)) {
        // auto-queen on promotion
        var move = NormalMove(from: _selected!, to: sq);
        if (widget.position.board.roleAt(_selected!) == Role.pawn &&
            (sq.rank == Rank.eighth || sq.rank == Rank.first)) {
          move = NormalMove(from: _selected!, to: sq, promotion: Role.queen);
        }
        final (newPos, san) = widget.position.makeSan(move);
        widget.onMove!(move, san);
        setState(() => _selected = null);
        return;
      }
      setState(() => _selected = widget.position.board.pieceAt(sq) != null ? sq : null);
    } else {
      final p = widget.position.board.pieceAt(sq);
      if (p != null && p.color == widget.position.turn) {
        setState(() => _selected = sq);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranks = List.generate(8, (i) => 7 - i); // rank index 7..0 (rank8..rank1)
    final files = List.generate(8, (i) => i);
    final rows = widget.whiteOnBottom ? ranks : ranks.reversed.toList();
    final cols = widget.whiteOnBottom ? files : files.reversed.toList();

    return Column(
      children: [
        for (final ri in rows)
          Expanded(
            child: Row(
              children: [
                for (final fi in cols)
                  Expanded(child: _square(ri, fi)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _square(int ri, int fi) {
    final sq = Square.fromCoords(File.values[fi], Rank.values[ri]);
    final piece = widget.position.board.pieceAt(sq);
    final isDark = (ri + fi) % 2 == 0;
    Color bg = isDark ? const Color(0xFF7A9A6A) : const Color(0xFFE8E4D8);
    if (widget.lastMove.contains(sq)) bg = isDark ? const Color(0xFFB8A94A) : const Color(0xFFE8D97A);
    if (widget.highlight.contains(sq)) bg = const Color(0xFF4A90D9);
    final glyph = piece != null ? _glyphs[piece.color == Side.white ? piece.role.name[0].toUpperCase() : piece.role.name[0]] : null;

    return GestureDetector(
      onTap: () => _tap(sq),
      child: Container(
        color: bg,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (glyph != null)
              Text(glyph, style: const TextStyle(fontSize: 30)),
            if (_targets.contains(sq))
              Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle)),
            if (_selected == sq)
              Container(decoration: BoxDecoration(border: Border.all(color: Colors.teal, width: 2))),
          ],
        ),
      ),
    );
  }
}
