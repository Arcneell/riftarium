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
  (ref) => ref.watch(authControllerProvider.select((state) => state.profile?.id)),
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

/// Mes matchs terminés, plus récents d'abord.
final historyProvider = FutureProvider.autoDispose<HistoryPage>((ref) async {
  final signedIn = ref.watch(
    authControllerProvider.select((state) => state.isSignedIn),
  );
  if (!signedIn) return const HistoryPage(items: []);
  return ref.watch(playApiProvider).history(size: 50);
});

/// Mes statistiques de parties suivies.
final playStatsProvider = FutureProvider.autoDispose<PlayStats>((ref) async {
  final signedIn = ref.watch(
    authControllerProvider.select((state) => state.isSignedIn),
  );
  if (!signedIn) return const PlayStats();
  return ref.watch(playApiProvider).stats();
});
