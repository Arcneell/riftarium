import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../cards/data/cards_api.dart';
import '../../cards/domain/card.dart';
import '../data/game_store.dart';
import '../data/legends_repository.dart';
import '../domain/game_actions.dart';
import '../domain/game_engine.dart';
import '../domain/game_mode.dart';
import '../domain/game_state.dart';
import '../domain/player.dart';
import '../domain/saved_table.dart';

/// Maintien de l'écran allumé pendant une partie. Passe par une interface :
/// le plugin natif n'existe pas sous `flutter test`, où l'on injecte
/// [NoScreenAwake].
abstract class ScreenAwake {
  Future<void> enable();
  Future<void> disable();
}

class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();

  @override
  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } on Object {
      // Plateforme sans veille pilotable : la partie continue sans.
    }
  }

  @override
  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } on Object {
      // Idem.
    }
  }
}

/// Ne touche à rien : tests et plateformes sans plugin.
class NoScreenAwake implements ScreenAwake {
  const NoScreenAwake();

  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

final screenAwakeProvider = Provider<ScreenAwake>(
  (ref) => const WakelockScreenAwake(),
);

final gameStoreProvider = Provider<GameStore>((ref) => const FileGameStore());

/// Horloge de la table, injectable : les tests fixent l'instant courant pour
/// vérifier ce qui dépend du temps (fin de la ronde en tournoi).
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final legendsCacheProvider = Provider<LegendsCacheStore>(
  (ref) => const FileLegendsCacheStore(),
);

final legendsRepositoryProvider = Provider<LegendsRepository>(
  (ref) => LegendsRepository(
    api: ref.watch(cardsApiProvider),
    cache: ref.watch(legendsCacheProvider),
  ),
);

/// Légendes groupées, chargées à l'ouverture du sélecteur seulement : la table
/// de jeu ne dépend jamais d'une requête réseau.
final legendsProvider = FutureProvider<List<LegendGroup>>(
  (ref) => ref.watch(legendsRepositoryProvider).load(),
);

/// Partie sauvegardée trouvée au démarrage de l'écran (panneau « Reprendre »).
final savedGameProvider = FutureProvider<GameState?>(
  (ref) => ref.watch(gameStoreProvider).read(),
);

final gameControllerProvider = NotifierProvider<GameController, GameState?>(
  GameController.new,
);

/// Pilote la partie : applique le moteur puis sauvegarde. `null` = personne
/// n'est à table, l'écran affiche la configuration.
class GameController extends Notifier<GameState?> implements GameActions {
  @override
  GameState? build() => null;

  GameStore get _store => ref.read(gameStoreProvider);

  void start({
    required GameMode mode,
    required List<Player> players,
    String? firstPlayerId,
    Duration? roundLimit,
  }) {
    _apply(
      GameEngine.start(
        mode: mode,
        players: players,
        firstPlayerId: firstPlayerId,
        roundLimit: roundLimit,
      ),
    );
    // La table est retenue au-delà de la partie : quitter n'efface que la
    // sauvegarde de reprise, la prochaine configuration retrouve les joueurs,
    // le format et la durée de ronde.
    unawaited(
      _store.writeTable(
        SavedTable(mode: mode, players: players, roundLimit: roundLimit),
      ),
    );
  }

  /// Reprend une partie relue depuis la sauvegarde.
  void resume(GameState saved) => _apply(saved);

  @override
  void addPoint(String playerId) =>
      _mutate((state) => GameEngine.addPoint(state, playerId: playerId));

  @override
  void removePoint(String playerId) =>
      _mutate((state) => GameEngine.removePoint(state, playerId: playerId));

  @override
  void exhaustion({required String fromPlayerId, required String toPlayerId}) =>
      _mutate(
        (state) => GameEngine.exhaustion(
          state,
          fromPlayerId: fromPlayerId,
          toPlayerId: toPlayerId,
        ),
      );

  @override
  void addXp(String playerId, [int amount = 1]) => _mutate(
    (state) => GameEngine.addXp(state, playerId: playerId, amount: amount),
  );

  @override
  void spendXp(String playerId, [int amount = 1]) => _mutate(
    (state) => GameEngine.spendXp(state, playerId: playerId, amount: amount),
  );

  @override
  void setXp(String playerId, int value) => _mutate(
    (state) => GameEngine.setXp(state, playerId: playerId, value: value),
  );

  @override
  void nextTurn() => _mutate(GameEngine.nextTurn);

  @override
  void undo() => _mutate(GameEngine.undo);

  @override
  void newRound({String? firstPlayerId}) => _mutate(
    (state) => GameEngine.newRound(state, firstPlayerId: firstPlayerId),
  );

  @override
  void callTime() => _mutate(GameEngine.callTime);

  @override
  void reset() => _mutate((state) => GameEngine.reset(state));

  @override
  void renamePlayer(String playerId, String name) => _mutate(
    (state) => GameEngine.updatePlayer(state, playerId: playerId, name: name),
  );

  @override
  void setLegend(String playerId, RiftCard? legend) => _mutate(
    (state) => GameEngine.updatePlayer(
      state,
      playerId: playerId,
      legend: legend,
      clearLegend: legend == null,
    ),
  );

  /// Le rappel des ajustements du premier tour a été vu : il ne revient pas.
  @override
  void markHintSeen() => _mutate(
    (state) => state.hintSeen ? state : state.copyWith(hintSeen: true),
  );

  /// Quitte la table et efface la sauvegarde.
  @override
  void quit() {
    state = null;
    unawaited(_store.clear());
    ref.invalidate(savedGameProvider);
  }

  void _mutate(GameState Function(GameState state) change) {
    final current = state;
    if (current == null) return;
    _apply(change(current));
  }

  void _apply(GameState next) {
    state = next;
    unawaited(_store.write(next));
  }
}
