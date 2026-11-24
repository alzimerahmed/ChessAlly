import 'package:chessground/chessground.dart' show ChessboardColorScheme, PieceAssets;
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'theme.dart';

const _glyphs = {
  'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚',
  'P': '♙', 'N': '♘', 'B': '♗', 'R': '♖', 'Q': '♕', 'K': '♔',
};

/// A chessboard: tap to select, tap target to move.
/// Pieces and board theme come from [boardAppearance].
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
      child: ValueListenableBuilder<BoardAppearance>(
        valueListenable: boardAppearance,
        builder: (context, appearance, _) {
          final scheme = appearance.theme.scheme;
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // themed board texture/colors + coordinates
                whiteOnBottom ? scheme.whiteCoordBackground : scheme.blackCoordBackground,
                // interactive overlay grid
                _BoardGrid(
                  position: position,
                  whiteOnBottom: whiteOnBottom,
                  onMove: onMove,
                  highlight: highlight,
                  lastMove: lastMove,
                  interactive: interactive,
                  scheme: scheme,
                  pieceAssets: appearance.pieces.assets,
                ),
              ],
            ),
          );
        },
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
  final ChessboardColorScheme scheme;
  final PieceAssets pieceAssets;
  const _BoardGrid({
    required this.position,
    required this.whiteOnBottom,
    this.onMove,
    required this.highlight,
    required this.lastMove,
    required this.interactive,
    required this.scheme,
    required this.pieceAssets,
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
    final scheme = widget.scheme;
    final lastMoveColor = scheme.lastMove.solidColor ?? Colors.amber.withValues(alpha: 0.45);
    final selectedColor = scheme.selected.solidColor ?? Colors.teal.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: () => _tap(sq),
      child: Container(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.lastMove.contains(sq))
              Positioned.fill(child: ColoredBox(color: lastMoveColor)),
            if (widget.highlight.contains(sq))
              const Positioned.fill(child: ColoredBox(color: Color(0x664A90D9))),
            if (_selected == sq)
              Positioned.fill(child: ColoredBox(color: selectedColor)),
            if (piece != null)
              Positioned.fill(
                child: _PieceImage(piece: piece, assets: widget.pieceAssets),
              ),
            if (_targets.contains(sq))
              Center(
                child: FractionallySizedBox(
                  widthFactor: piece != null ? 1.0 : 0.28,
                  heightFactor: piece != null ? 1.0 : 0.28,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: piece == null ? scheme.validMoves : Colors.transparent,
                      border: piece != null
                          ? Border.all(color: scheme.validMoves, width: 3)
                          : null,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PieceImage extends StatelessWidget {
  final Piece piece;
  final PieceAssets assets;
  const _PieceImage({required this.piece, required this.assets});

  @override
  Widget build(BuildContext context) {
    final image = assets[piece.kind];
    if (image == null) return const SizedBox.shrink();
    return Image(
      image: image,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Center(
        child: Text(
          _glyphs[piece.fenChar.replaceAll('~', '')] ?? '?',
          style: const TextStyle(fontSize: 30),
        ),
      ),
    );
  }
}
