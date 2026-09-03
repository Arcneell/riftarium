import 'game_mode.dart';
import 'player.dart';

/// La dernière table jouée : le format et les joueurs (noms, légendes,
/// équipes). Gardée après la fin d'une partie pour préremplir la
/// configuration — relancer avec les mêmes personnes, en changeant d'équipe
/// ou de format, ne demande plus de tout ressaisir.
class SavedTable {
  const SavedTable({required this.mode, required this.players});

  final GameMode mode;
  final List<Player> players;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'mode': mode.id,
    'players': players.map((player) => player.toJson()).toList(),
  };

  /// Relecture tolérante : mode inconnu ou joueurs absents → null, la
  /// configuration repart de ses valeurs par défaut.
  static SavedTable? fromJson(Object? source) {
    if (source is! Map) return null;
    final json = Map<String, dynamic>.from(source);
    final mode = GameMode.byId(json['mode']);
    if (mode == null) return null;
    final players = (json['players'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Player.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    if (players.isEmpty) return null;
    return SavedTable(mode: mode, players: players);
  }
}
