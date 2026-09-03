import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../cards/application/cards_controller.dart';
import '../data/collection_api.dart';
import '../domain/collection.dart';
import 'collection_controller.dart';
import 'wishlist_controller.dart';

/// Lots possédés d'une carte donnée : ce qu'affiche le stepper de la fiche.
final cardCollectionProvider =
    AsyncNotifierProvider.family<
      CardCollectionController,
      CardCollectionState,
      String
    >(CardCollectionController.new);

/// Quantité possédée d'une carte, pilotée depuis sa fiche.
///
/// Le stepper agit sur un seul lot — le lot unique quand il n'y en a qu'un,
/// sinon le lot NM/EN, celui que crée l'ajout par défaut. Les collections à
/// plusieurs lots se règlent finement depuis l'onglet Collection.
class CardCollectionController
    extends FamilyAsyncNotifier<CardCollectionState, String> {
  bool _disposed = false;

  CollectionApi get _api => ref.read(collectionApiProvider);

  @override
  Future<CardCollectionState> build(String cardId) async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );
    if (!signedIn) return CardCollectionState.empty(cardId);
    return _api.cardState(cardId);
  }

  /// Ajoute ou retire des exemplaires au lot principal.
  Future<void> adjust(int delta) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final target = current.mainEntry;
    final qty = ((target?.qty ?? 0) + delta).clamp(0, maxCollectionQty);
    if (qty == (target?.qty ?? 0)) return;
    await setQuantity(
      qty,
      condition: target?.condition ?? defaultCondition,
      lang: target?.lang ?? defaultLang,
    );
  }

  /// Fixe la quantité du lot (état, langue) — 0 le supprime.
  Future<void> setQuantity(
    int qty, {
    String condition = defaultCondition,
    String lang = defaultLang,
  }) async {
    final previous = state.valueOrNull;
    if (previous != null) {
      state = AsyncData(_withQuantity(previous, qty, condition, lang));
    }
    try {
      await _api.setQuantity(
        cardId: arg,
        qty: qty,
        condition: condition,
        lang: lang,
      );
    } catch (_) {
      if (!_disposed && previous != null) state = AsyncData(previous);
      rethrow;
    }
    if (_disposed) return;
    _invalidateDependents();
    final next = await AsyncValue.guard(() => _api.cardState(arg));
    if (!_disposed) state = next;
  }

  /// Tout ce qui affiche une quantité possédée dépend de cette carte : la
  /// collection, la progression par set, la cartothèque (`owned_qty` et le
  /// filtre « possédées ») et la fiche elle-même. Ces vues repartiront du
  /// serveur à leur prochaine lecture.
  void _invalidateDependents() {
    ref.invalidate(collectionControllerProvider);
    ref.invalidate(collectionProgressProvider);
    ref.invalidate(cardsListProvider);
    ref.invalidate(wishlistControllerProvider);
    ref.invalidate(cardDetailProvider(arg));
  }

  CardCollectionState _withQuantity(
    CardCollectionState current,
    int qty,
    String condition,
    String lang,
  ) {
    final entries = entriesWithQuantity(current.entries, qty, condition, lang);
    return current.copyWith(
      entries: entries,
      totalQty: entries.fold<int>(0, (total, entry) => total + entry.qty),
    );
  }
}
