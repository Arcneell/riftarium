import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../collection/domain/collection.dart';
import '../../play/domain/history.dart';
import '../data/social_api.dart';
import '../domain/achievement.dart';
import '../domain/public_profile.dart';

/// Taille de page de la collection d'un profil public.
const profileCollectionPageSize = 60;

/// Deux caractères au minimum, comme côté API (`GET /users/search`).
const userSearchMinLength = 2;

/// Délai avant d'envoyer la recherche : la saisie ne déclenche pas un appel
/// par caractère.
const userSearchDelay = Duration(milliseconds: 300);

/// Tous mes hauts faits (catalogue complet, avec la progression). Vide et sans
/// appel hors session.
final myAchievementsProvider = FutureProvider.autoDispose<List<Achievement>>((
  ref,
) async {
  final signedIn = ref.watch(
    authControllerProvider.select((state) => state.isSignedIn),
  );
  if (!signedIn) return const [];
  return ref.watch(socialApiProvider).achievements();
});

/// Mes suivis et mes abonnés.
final followsProvider = FutureProvider.autoDispose<FollowLists>((ref) async {
  final signedIn = ref.watch(
    authControllerProvider.select((state) => state.isSignedIn),
  );
  if (!signedIn) return const FollowLists();
  return ref.watch(socialApiProvider).follows();
});

/// Recherche de comptes par pseudo. En dessous de [userSearchMinLength]
/// caractères, aucune requête n'est envoyée.
final userSearchProvider = FutureProvider.autoDispose
    .family<List<SocialUser>, String>((ref, query) async {
      final trimmed = query.trim();
      if (trimmed.length < userSearchMinLength) return const [];
      return ref.watch(socialApiProvider).search(trimmed);
    });

/// Historique public d'un joueur (chargé seulement quand la section est
/// visible).
final profileHistoryProvider = FutureProvider.autoDispose
    .family<HistoryPage, String>(
      (ref, handle) => ref.watch(socialApiProvider).history(handle, size: 20),
    );

final publicProfileProvider = AsyncNotifierProvider.autoDispose
    .family<PublicProfileController, PublicProfile, String>(
      PublicProfileController.new,
    );

/// Profil public consulté : lecture, puis suivi en un geste.
///
/// Le bouton « Suivre » bascule d'abord l'affichage, puis appelle l'API : le
/// compteur d'abonnés suit tout de suite. En cas d'échec, l'état d'avant est
/// remis et l'erreur remonte à l'écran.
class PublicProfileController
    extends AutoDisposeFamilyAsyncNotifier<PublicProfile, String> {
  String get handle => arg;

  @override
  Future<PublicProfile> build(String arg) =>
      ref.watch(socialApiProvider).profile(arg);

  Future<void> reload() async {
    state = const AsyncLoading<PublicProfile>().copyWithPrevious(state);
    state = await AsyncValue.guard(
      () => ref.read(socialApiProvider).profile(handle),
    );
  }

  Future<void> toggleFollow() async {
    final current = state.valueOrNull;
    if (current == null || current.isMe) return;
    final next = !current.isFollowed;
    state = AsyncData(
      current.copyWith(
        isFollowed: next,
        followersCount: (current.followersCount + (next ? 1 : -1)).clamp(
          0,
          1 << 30,
        ),
      ),
    );
    try {
      final api = ref.read(socialApiProvider);
      if (next) {
        await api.follow(handle);
      } else {
        await api.unfollow(handle);
      }
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
    ref.invalidate(followsProvider);
  }
}

/// Cartes chargées d'une collection publique, page après page.
class ProfileCards {
  const ProfileCards({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.loadingMore = false,
  });

  final List<CollectionItem> items;
  final int total;
  final int page;
  final bool loadingMore;

  bool get hasMore => items.length < total;

  ProfileCards copyWith({
    List<CollectionItem>? items,
    int? total,
    int? page,
    bool? loadingMore,
  }) => ProfileCards(
    items: items ?? this.items,
    total: total ?? this.total,
    page: page ?? this.page,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

final profileCollectionProvider = AsyncNotifierProvider.autoDispose
    .family<ProfileCollectionController, ProfileCards, String>(
      ProfileCollectionController.new,
    );

/// Collection d'un profil public : première page au chargement, les suivantes
/// à la demande.
class ProfileCollectionController
    extends AutoDisposeFamilyAsyncNotifier<ProfileCards, String> {
  bool _disposed = false;

  String get handle => arg;

  @override
  Future<ProfileCards> build(String arg) async {
    ref.onDispose(() => _disposed = true);
    final page = await ref
        .watch(socialApiProvider)
        .collection(arg, size: profileCollectionPageSize);
    return ProfileCards(items: page.items, total: page.total, page: page.page);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref
          .read(socialApiProvider)
          .collection(
            handle,
            page: current.page + 1,
            size: profileCollectionPageSize,
          );
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
