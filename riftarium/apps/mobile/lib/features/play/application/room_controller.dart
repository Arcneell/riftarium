import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_exception.dart';
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
/// arrête le minuteur). Une erreur réseau pendant un battement ne casse pas
/// l'affichage : le salon connu reste à l'écran et le prochain battement
/// réessaie.
final roomControllerProvider = AsyncNotifierProvider.autoDispose
    .family<RoomController, Room, String>(RoomController.new);

class RoomController extends AutoDisposeFamilyAsyncNotifier<Room, String> {
  Timer? _timer;
  bool _disposed = false;

  String get code => arg;

  PlayApi get _api => ref.read(playApiProvider);

  @override
  Future<Room> build(String arg) async {
    final interval = ref.watch(playPollIntervalProvider);
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      _timer = null;
    });
    final room = await _api.room(arg);
    if (interval > Duration.zero) {
      _timer = Timer.periodic(interval, (_) => refresh());
    }
    return room;
  }

  /// Un battement de sondage : silencieux en cas d'erreur réseau.
  Future<void> refresh() async {
    try {
      final room = await _api.room(code);
      _publish(room);
    } on ApiException {
      // Le salon affiché reste en place ; le prochain battement réessaie.
    }
  }

  /// Recharge en laissant remonter l'erreur (bouton « Réessayer »).
  Future<void> reload() async {
    state = const AsyncLoading<Room>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _api.room(code));
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

  /// L'invité quitte le salon.
  Future<void> leave() async {
    await _api.leaveRoom(code);
  }

  /// L'hôte annule le salon.
  Future<void> cancel() async {
    await _api.cancelRoom(code);
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

  void _publish(Room room) {
    if (_disposed) return;
    state = AsyncData(room);
  }
}
