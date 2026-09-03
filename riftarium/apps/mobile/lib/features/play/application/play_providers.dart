import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/play_api.dart';
import '../domain/history.dart';
import '../domain/match.dart';
import '../domain/play_stats.dart';

/// Cadence du sondage des écrans suivis : 2 s côté mobile (contrat).
///
/// Surchargé à `Duration.zero` dans les tests : aucun minuteur n'est alors
/// lancé, les rafraîchissements se déclenchent à la main.
final playPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

/// Mon identifiant de compte, ou null hors session.
final myUserIdProvider = Provider<int?>(
  (ref) =>
      ref.watch(authControllerProvider.select((state) => state.profile?.id)),
);

/// Mon salon actif et/ou mon match en cours. Vide et sans appel hors session.
final currentPlayProvider = FutureProvider.autoDispose<CurrentPlay>((
  ref,
) async {
  final signedIn = ref.watch(
    authControllerProvider.select((state) => state.isSignedIn),
  );
  if (!signedIn) return const CurrentPlay();
  return ref.watch(playApiProvider).current();
});

/// Taille d'une page d'historique (le contrat plafonne `size` à 50).
const historyPageSize = 20;

final historyProvider =
    AsyncNotifierProvider.autoDispose<HistoryController, HistoryFeed>(
      HistoryController.new,
    );

/// Mes matchs terminés, plus récents d'abord : la première page au chargement,
/// les suivantes à la demande (« Charger la suite »). Vide et sans appel hors
/// session.
class HistoryController extends AutoDisposeAsyncNotifier<HistoryFeed> {
  bool _disposed = false;

  @override
  Future<HistoryFeed> build() async {
    ref.onDispose(() => _disposed = true);
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    if (!signedIn) return const HistoryFeed();
    final page = await ref
        .watch(playApiProvider)
        .history(size: historyPageSize);
    return HistoryFeed(items: page.items, total: page.total, page: page.page);
  }

  /// Page suivante ajoutée à la suite. Un échec laisse la liste en place et
  /// remonte l'erreur : l'écran l'affiche sans perdre ce qui est déjà lu.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(playApiProvider)
          .history(page: current.page + 1, size: historyPageSize);
      if (_disposed) return;
      state = AsyncData(
        current.copyWith(
          items: [...current.items, ...next.items],
          page: next.page,
          total: next.total,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (!_disposed) state = AsyncData(current.copyWith(loadingMore: false));
      rethrow;
    }
  }
}

/// Mes statistiques de parties suivies.
final playStatsProvider = FutureProvider.autoDispose<PlayStats>((ref) async {
  final signedIn = ref.watch(
    authControllerProvider.select((state) => state.isSignedIn),
  );
  if (!signedIn) return const PlayStats();
  return ref.watch(playApiProvider).stats();
});
