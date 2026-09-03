import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
import '../../../core/poller.dart';
import '../../cards/domain/card.dart';
import '../../decks/data/decks_api.dart';
import '../../decks/domain/deck.dart';
import '../data/play_api.dart';
import '../domain/match.dart';
import '../domain/room.dart';
import 'play_providers.dart';

/// Salon d'attente, tenu à jour par sondage.
///
/// Le serveur ne pousse rien : on redemande le salon toutes les deux secondes
/// tant que l'écran est monté (le provider est `autoDispose`, quitter l'écran
/// arrête le [Poller]). Une erreur réseau pendant un battement ne casse pas
/// l'affichage : le salon connu reste à l'écran, l'attente double jusqu'au
/// retour du réseau. Le sondage s'arrête de lui-même dès qu'il n'y a plus rien
/// à attendre : salon annulé, terminé, expiré, ou partie lancée.
final roomControllerProvider = AsyncNotifierProvider.autoDispose
    .family<RoomController, Room, String>(RoomController.new);

class RoomController extends AutoDisposeFamilyAsyncNotifier<Room, String> {
  Poller? _poller;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;

  /// Version du dernier salon adopté : une réponse en retard est ignorée.
  int _version = -1;

  String get code => arg;

  PlayApi get _api => ref.read(playApiProvider);

  @override
  Future<Room> build(String arg) async {
    final interval = ref.watch(playPollIntervalProvider);
    final poller = Poller(tick: _tick, interval: interval);
    _poller = poller;
    if (interval > Duration.zero) {
      // En arrière-plan, plus de battement ; au retour, un battement part
      // aussitôt pour rattraper ce qui s'est passé entre-temps. Le minuteur
      // n'existe pas dans les tests (intervalle nul) : pas de binding requis.
      _lifecycle = AppLifecycleListener(
        onStateChange: (value) => value == AppLifecycleState.resumed
            ? poller.resume()
            : poller.pause(),
      );
    }
    ref.onDispose(() {
      _disposed = true;
      poller.dispose();
      _lifecycle?.dispose();
      _lifecycle = null;
      _poller = null;
    });
    final room = await _api.room(arg);
    _version = room.version;
    if (_awaited(room)) poller.start();
    return room;
  }

  /// Un battement de sondage : silencieux en cas d'erreur réseau.
  Future<void> refresh() async {
    try {
      await _tick();
    } on ApiException {
      // Le salon affiché reste en place ; le prochain battement réessaie.
    }
  }

  /// Recharge en laissant remonter l'erreur (bouton « Réessayer »).
  Future<void> reload() async {
    state = const AsyncLoading<Room>().copyWithPrevious(state);
    final next = await AsyncValue.guard(() => _api.room(code));
    state = next;
    final room = next.valueOrNull;
    if (room == null) return;
    // Une reprise explicite fait foi, quelle que soit la version connue.
    _version = room.version;
    if (_awaited(room)) {
      _poller?.start();
    } else {
      _poller?.stop();
    }
  }

  Future<void> setReady(bool ready) => _updateMe(ready: ready);

  Future<void> setLegend(RiftCard? legend) =>
      _updateMe(legendCardId: legend?.id, clearLegend: legend == null);

  /// Choix d'un deck. La légende part avec lui : on relit le deck complet
  /// (`GET /decks/{id}`) pour prendre la carte de zone Légende **telle qu'elle
  /// y figure** — même variante (alt-art, overnumbered, signature) — et
  /// l'envoyer dans le même `PUT`. Le joueur reste libre d'en changer ensuite.
  Future<void> setDeck(Deck? deck) async {
    if (deck == null) {
      await _updateMe(clearDeck: true, ready: false);
      return;
    }
    RiftCard? legend;
    try {
      legend = (await ref.read(decksApiProvider).get(deck.id)).legend;
    } on ApiException {
      // Le deck n'a pas pu être relu : on garde ce que la liste en savait.
      legend = deck.legend;
    }
    // `legendCardId` nul laisse la légende courante en place : un deck sans
    // légende ne défait pas un choix déjà fait à la main.
    await _updateMe(deckId: deck.id, legendCardId: legend?.id, ready: false);
  }

  /// L'invité quitte le salon. L'API renvoie le salon à jour : on l'adopte.
  Future<void> leave() async {
    final room = await _api.leaveRoom(code);
    if (room != null) _publish(room);
  }

  /// L'hôte annule le salon (réponse : le salon en `cancelled`).
  Future<void> cancel() async {
    final room = await _api.cancelRoom(code);
    if (room != null) _publish(room);
  }

  /// L'invité rejoint le siège libre. 409 si le salon s'est rempli entre-temps.
  Future<void> join() async {
    _publish(await _api.joinRoom(code));
  }

  /// L'hôte lance la partie avec le joueur tiré au sort.
  Future<Match> start(int firstPlayerId) async {
    final match = await _api.startMatch(code, firstPlayerId: firstPlayerId);
    await refresh();
    return match;
  }

  /// Envoie mon choix complet : l'API remplace les trois champs à chaque appel,
  /// il faut donc renvoyer ceux qui ne changent pas.
  Future<void> _updateMe({
    String? legendCardId,
    int? deckId,
    bool? ready,
    bool clearLegend = false,
    bool clearDeck = false,
  }) async {
    final room = state.valueOrNull;
    final me = room?.playerOf(ref.read(myUserIdProvider));
    final room2 = await _api.updateMe(
      code,
      legendCardId: clearLegend ? null : (legendCardId ?? me?.legend?.id),
      deckId: clearDeck ? null : (deckId ?? me?.deck?.id),
      ready: ready ?? me?.ready ?? false,
    );
    if (room2 != null) {
      _publish(room2);
    } else {
      await refresh();
    }
  }

  Future<void> _tick() async => _publish(await _api.room(code));

  void _publish(Room room) {
    if (_disposed) return;
    // Réponse arrivée après une plus récente (réseau lent) : on l'oublie.
    if (room.version < _version) return;
    _version = room.version;
    state = AsyncData(room);
    if (!_awaited(room)) _poller?.stop();
  }

  /// Il reste quelque chose à attendre de ce salon. Une fois la partie lancée,
  /// c'est le match qui se sonde ; un salon fermé ne bougera plus.
  static bool _awaited(Room room) =>
      !room.isCancelled &&
      !room.isFinished &&
      !room.isPlaying &&
      !room.expired();
}
