import '../../cards/domain/card.dart';

/// Ce que la table sait demander au moteur.
///
/// La partie libre branche ces gestes sur `GameController` (sauvegarde
/// locale) ; la partie suivie sur son propre contrôleur, qui applique le même
/// moteur puis synchronise l'instantané avec le serveur. La table
/// (`GameTableView`, `PlayerPanel`) ne connaît que cette interface.
abstract class GameActions {
  void addPoint(String playerId);
  void removePoint(String playerId);
  void exhaustion({required String fromPlayerId, required String toPlayerId});
  void addXp(String playerId, [int amount]);
  void spendXp(String playerId, [int amount]);
  void setXp(String playerId, int value);
  void nextTurn();
  void undo();
  void newRound();
  void reset();
  void renamePlayer(String playerId, String name);
  void setLegend(String playerId, RiftCard? legend);
  void markHintSeen();

  /// Quitte la table. En partie suivie, l'abandon passe par l'écran : rien
  /// n'est effacé ici.
  void quit();
}
