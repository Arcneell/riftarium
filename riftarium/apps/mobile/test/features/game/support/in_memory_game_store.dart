import 'dart:convert';

import 'package:riftarium_mobile/features/game/data/game_store.dart';
import 'package:riftarium_mobile/features/game/domain/game_state.dart';
import 'package:riftarium_mobile/features/game/domain/saved_table.dart';

/// Sauvegarde en mémoire : la table de jeu se teste sans toucher au disque.
/// Le JSON est bien produit et relu, comme sur disque, pour que la
/// sérialisation reste couverte. Réservée aux tests — la production n'a que
/// `FileGameStore`.
class InMemoryGameStore implements GameStore {
  InMemoryGameStore([
    Map<String, dynamic>? initial,
    Map<String, dynamic>? table,
  ]) : _saved = initial,
       _table = table;

  Map<String, dynamic>? _saved;
  Map<String, dynamic>? _table;

  /// Nombre d'écritures : pratique pour vérifier qu'une action sauvegarde.
  int writes = 0;

  @override
  Future<GameState?> read() async => GameState.fromJson(_saved);

  @override
  Future<bool> write(GameState state) async {
    _saved = jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>;
    writes++;
    return true;
  }

  @override
  Future<void> clear() async => _saved = null;

  @override
  Future<SavedTable?> readTable() async => SavedTable.fromJson(_table);

  @override
  Future<bool> writeTable(SavedTable table) async {
    _table = jsonDecode(jsonEncode(table.toJson())) as Map<String, dynamic>;
    return true;
  }
}
