import 'game_mode.dart';
import 'player.dart';

/// La dernière table jouée : le format et les joueurs (noms, légendes,
/// équipes). Gardée après la fin d'une partie pour préremplir la
/// configuration — relancer avec les mêmes personnes, en changeant d'équipe
/// ou de format, ne demande plus de tout ressaisir.
class SavedTable {
  const SavedTable({
    required this.mode,
    required this.players,
    this.roundLimit,
  });

  final GameMode mode;
  final List<Player> players;

  /// Tournoi : durée de ronde choisie la dernière fois, null pour « sans
  /// limite ». Ne veut rien dire hors tournoi (le format ne l'utilise pas).
  final Duration? roundLimit;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'mode': mode.id,
    'players': players.map((player) => player.toJson()).toList(),
    'round_limit_s': roundLimit?.inSeconds,
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
    // Table d'avant ce champ (ou « sans limite ») : null, la configuration
    // reprend sa valeur par défaut.
    final limitSeconds = (json['round_limit_s'] as num?)?.toInt();
    return SavedTable(
      mode: mode,
      players: players,
      roundLimit: limitSeconds == null || limitSeconds <= 0
          ? null
          : Duration(seconds: limitSeconds),
    );
  }
}
