import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../../cards/domain/card.dart';
import '../../game/domain/game_actions.dart';
import '../../game/domain/game_engine.dart';
import '../../game/domain/game_state.dart';
import '../data/play_api.dart';
import '../domain/match.dart';
import '../domain/match_board.dart';
import 'play_providers.dart';

/// Délai avant l'envoi de l'instantané : plusieurs gestes rapprochés (trois
/// points de suite) ne font qu'un seul `PUT state`.
const Duration kPlaySyncDebounce = Duration(milliseconds: 300);

/// État de la synchronisation, affiché discrètement sur la table de l'hôte.
enum PlaySync {
  /// L'instantané du serveur est à jour.
  synced,

  /// Des gestes attendent leur envoi.
  pending,

  /// Le dernier envoi a échoué : la table continue, l'envoi repartira.
  offline,
}

/// Match suivi vu par l'écran : les données du serveur, la table du compteur
/// et l'état de la synchronisation.
class TrackedMatch {
  const TrackedMatch({
    required this.match,
    required this.board,
    this.sync = PlaySync.synced,
  });

  final Match match;
  final GameState board;
  final PlaySync sync;

  TrackedMatch copyWith({Match? match, GameState? board, PlaySync? sync}) =>
      TrackedMatch(
        match: match ?? this.match,
        board: board ?? this.board,
        sync: sync ?? this.sync,
      );
}

/// Match suivi : table locale côté hôte, lecture seule côté invité.
///
/// L'hôte tient le compte : chaque geste applique le moteur en local puis part
/// vers `PUT /play/matches/{id}/state` avec la `version` connue. Un 409 signale
/// que le serveur a bougé : on recharge le match, puis on réapplique
/// l'instantané local sur la nouvelle version. L'invité, lui, ne fait que lire
/// ce que le sondage rapporte.
final trackedMatchControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TrackedMatchController, TrackedMatch, int>(
      TrackedMatchController.new,
    );

class TrackedMatchController
    extends AutoDisposeFamilyAsyncNotifier<TrackedMatch, int>
    implements GameActions {
  Timer? _poll;
  Timer? _debounce;
  bool _disposed = false;
  bool _sending = false;
  bool _again = false;

  int get matchId => arg;

  PlayApi get _api => ref.read(playApiProvider);

  /// Je tiens le compte : les gestes sont actifs et partent au serveur.
  bool get isHost {
    final match = state.valueOrNull?.match;
    return match != null && match.isHost(ref.read(myUserIdProvider));
  }

  @override
  Future<TrackedMatch> build(int arg) async {
    final interval = ref.watch(playPollIntervalProvider);
    ref.onDispose(() {
      _disposed = true;
      _poll?.cancel();
      _debounce?.cancel();
      _poll = null;
      _debounce = null;
    });
    final match = await _api.match(arg);
    if (interval > Duration.zero) {
      _poll = Timer.periodic(interval, (_) => refresh());
    }
    return TrackedMatch(match: match, board: boardOfMatch(match));
  }

  /// Un battement de sondage. Côté hôte, la table locale fait foi tant que le
  /// match est en cours : seul le statut du match est repris.
  Future<void> refresh() async {
    try {
      final match = await _api.match(matchId);
      _adopt(match, keepBoard: isHost && match.isLive);
    } on ApiException {
      // Réseau capricieux : le prochain battement réessaie.
    }
  }

  Future<void> reload() async {
    state = const AsyncLoading<TrackedMatch>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final match = await _api.match(matchId);
      return TrackedMatch(match: match, board: boardOfMatch(match));
    });
  }

  // --- Gestes de la table (GameActions) -----------------------------------

  @override
  void addPoint(String playerId) =>
      _play((board) => GameEngine.addPoint(board, playerId: playerId));

  @override
  void removePoint(String playerId) =>
      _play((board) => GameEngine.removePoint(board, playerId: playerId));

  @override
  void exhaustion({required String fromPlayerId, required String toPlayerId}) =>
      _play(
        (board) => GameEngine.exhaustion(
          board,
          fromPlayerId: fromPlayerId,
          toPlayerId: toPlayerId,
        ),
      );

  @override
  void addXp(String playerId, [int amount = 1]) => _play(
    (board) => GameEngine.addXp(board, playerId: playerId, amount: amount),
  );

  @override
  void spendXp(String playerId, [int amount = 1]) => _play(
    (board) => GameEngine.spendXp(board, playerId: playerId, amount: amount),
  );

  @override
  void setXp(String playerId, int value) => _play(
    (board) => GameEngine.setXp(board, playerId: playerId, value: value),
  );

  @override
  void nextTurn() => _play(GameEngine.nextTurn);

  @override
  void undo() => _play(GameEngine.undo);

  @override
  void newRound({String? firstPlayerId}) => _play(
    (board) => GameEngine.newRound(board, firstPlayerId: firstPlayerId),
  );

  /// Sans effet en partie suivie : pas de ronde chronométrée (modes duel et
  /// match seulement).
  @override
  void callTime() {}

  /// Sans effet en partie suivie : une rencontre ne se remet pas à zéro, elle
  /// se termine ou s'abandonne.
  @override
  void reset() {}

  /// Les noms viennent des comptes : ils ne se saisissent pas ici.
  @override
  void renamePlayer(String playerId, String name) {}

  /// Les légendes sont choisies dans le salon, avant le lancement.
  @override
  void setLegend(String playerId, RiftCard? legend) {}

  @override
  void markHintSeen() {}

  /// La table se referme sans rien effacer : le match vit sur le serveur.
  @override
  void quit() {}

  // --- Fin de partie ------------------------------------------------------

  /// L'hôte clôture : l'instantané part d'abord, puis le résultat.
  Future<void> finishMatch() async {
    final current = state.valueOrNull;
    if (current == null || !current.match.isLive) return;
    final winner = winnerUserIdOf(current.board, current.match);
    if (winner == null) return;
    _debounce?.cancel();
    await _send();
    final latest = state.valueOrNull ?? current;
    final match = await _api.finish(
      matchId,
      winnerUserId: winner,
      result: resultOfBoard(latest.board, latest.match),
    );
    _adopt(match);
  }

  Future<void> confirmResult() async => _adopt(await _api.confirm(matchId));

  Future<void> disputeResult() async => _adopt(await _api.dispute(matchId));

  Future<void> abandonMatch() async => _adopt(await _api.abandon(matchId));

  // --- Synchronisation ----------------------------------------------------

  void _play(GameState Function(GameState board) change) {
    final current = state.valueOrNull;
    if (current == null || !current.match.isLive || !isHost) return;
    final board = change(current.board);
    if (identical(board, current.board)) return;
    _publish(current.copyWith(board: board, sync: PlaySync.pending));
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(kPlaySyncDebounce, _send);
  }

  /// Envoie l'instantané courant. Un 409 = le serveur a une autre version :
  /// on le recharge, puis on réapplique la table locale.
  Future<void> _send() async {
    if (_disposed) return;
    if (_sending) {
      _again = true;
      return;
    }
    final start = state.valueOrNull;
    if (start == null || !start.match.isLive || !isHost) return;
    _sending = true;
    try {
      var version = start.match.version;
      for (var attempt = 0; attempt < 2; attempt++) {
        final current = state.valueOrNull;
        if (current == null || !current.match.isLive) break;
        try {
          final updated = await _api.putState(
            matchId,
            version: version,
            state: stateOfBoard(current.board, current.match),
          );
          _adopt(updated, keepBoard: true, sync: PlaySync.synced);
          break;
        } on ApiException catch (error) {
          if (error.statusCode == 409 && attempt == 0) {
            final fresh = await _api.match(matchId);
            _adopt(fresh, keepBoard: fresh.isLive);
            version = fresh.version;
            continue;
          }
          _mark(PlaySync.offline);
          break;
        }
      }
    } finally {
      _sending = false;
      if (_again && !_disposed) {
        _again = false;
        _schedule();
      }
    }
  }

  /// Reprend le match du serveur. `keepBoard` garde la table locale (l'hôte
  /// vient de la modifier), sinon elle est reconstruite depuis l'instantané.
  void _adopt(Match match, {bool keepBoard = false, PlaySync? sync}) {
    final current = state.valueOrNull;
    final board = keepBoard && current != null
        ? current.board
        : boardOfMatch(match);
    _publish(
      TrackedMatch(
        match: match,
        board: board,
        sync: sync ?? current?.sync ?? PlaySync.synced,
      ),
    );
  }

  void _mark(PlaySync sync) {
    final current = state.valueOrNull;
    if (current == null) return;
    _publish(current.copyWith(sync: sync));
  }

  void _publish(TrackedMatch value) {
    if (_disposed) return;
    state = AsyncData(value);
  }
}
