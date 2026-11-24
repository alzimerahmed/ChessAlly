import 'package:chessground/chessground.dart';
import 'package:flutter/material.dart';

/// A selectable board theme (square colors/texture + highlight colors).
class BoardThemeOption {
  const BoardThemeOption(this.id, this.label, this.scheme);
  final String id;
  final String label;
  final ChessboardColorScheme scheme;
}

/// Curated board themes, wood textures first.
const boardThemes = <BoardThemeOption>[
  BoardThemeOption('wood3', 'Walnut Wood', ChessboardColorScheme.wood3),
  BoardThemeOption('wood4', 'Rosewood', ChessboardColorScheme.wood4),
  BoardThemeOption('wood2', 'Oak Wood', ChessboardColorScheme.wood2),
  BoardThemeOption('wood', 'Classic Wood', ChessboardColorScheme.wood),
  BoardThemeOption('maple', 'Maple', ChessboardColorScheme.maple),
  BoardThemeOption('maple2', 'Honey Maple', ChessboardColorScheme.maple2),
  BoardThemeOption('leather', 'Leather', ChessboardColorScheme.leather),
  BoardThemeOption('brown', 'Brown', ChessboardColorScheme.brown),
  BoardThemeOption('green', 'Green Felt', ChessboardColorScheme.green),
  BoardThemeOption('blue', 'Tournament Blue', ChessboardColorScheme.blue),
  BoardThemeOption('grey', 'Slate', ChessboardColorScheme.grey),
  BoardThemeOption('metal', 'Metal', ChessboardColorScheme.metal),
];

BoardThemeOption boardThemeById(String? id) =>
    boardThemes.firstWhere((t) => t.id == id, orElse: () => boardThemes.first);

PieceSet pieceSetById(String? id) =>
    PieceSet.values.firstWhere((p) => p.name == id, orElse: () => PieceSet.cburnett);

/// Currently selected board theme + piece set.
class BoardAppearance {
  const BoardAppearance({required this.theme, required this.pieces});
  final BoardThemeOption theme;
  final PieceSet pieces;
}

/// Global appearance state — boards rebuild when this changes.
final boardAppearance = ValueNotifier<BoardAppearance>(
  BoardAppearance(theme: boardThemes.first, pieces: PieceSet.cburnett),
);
