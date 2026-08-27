import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/collection_api.dart';
import '../domain/collection.dart';

final wishlistControllerProvider =
    AsyncNotifierProvider<WishlistController, Wishlist>(WishlistController.new);

/// Liste de souhaits : chargée d'un bloc, modifiée carte par carte.
///
/// Comme sur le site, chaque modification est appliquée localement puis la
/// liste est rechargée : le total et la valeur estimée restent ceux du serveur.
class WishlistController extends AsyncNotifier<Wishlist> {
  bool _disposed = false;

  CollectionApi get _api => ref.read(collectionApiProvider);

  @override
  Future<Wishlist> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );
    if (!signedIn) return Wishlist.empty;
    return _api.wishlist();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<Wishlist>().copyWithPrevious(state);
    final next = await AsyncValue.guard(() => _api.wishlist());
    if (!_disposed) state = next;
  }

  /// Quantité souhaitée (bornée par l'API entre 1 et 99).
  Future<void> setQuantity({required String cardId, required int qty}) {
    final wanted = qty.clamp(1, maxWishQty);
    return _mutate(
      optimistic: (current) => Wishlist(
        total: current.total,
        valueEur: current.valueEur,
        items: [
          for (final item in current.items)
            item.card.id == cardId ? item.copyWith(qty: wanted) : item,
        ],
      ),
      action: () => _api.setWish(cardId: cardId, qty: wanted),
    );
  }

  Future<void> remove(String cardId) => _mutate(
    optimistic: (current) {
      final items = current.items
          .where((item) => item.card.id != cardId)
          .toList();
      return Wishlist(
        total: items.length,
        valueEur: current.valueEur,
        items: items,
      );
    },
    action: () => _api.removeWish(cardId),
  );

  Future<void> _mutate({
    required Wishlist Function(Wishlist) optimistic,
    required Future<void> Function() action,
  }) async {
    final previous = state.valueOrNull;
    if (previous != null) state = AsyncData(optimistic(previous));
    try {
      await action();
    } catch (_) {
      if (!_disposed && previous != null) state = AsyncData(previous);
      rethrow;
    }
    if (_disposed) return;
    await refresh();
  }
}
