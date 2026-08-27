import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/adaptive.dart';
import '../../../../app/router.dart';
import '../../../../core/api_exception.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cards/domain/card.dart';
import '../../application/card_collection_controller.dart';
import '../../application/wishlist_controller.dart';
import '../../data/collection_api.dart';
import '../../domain/collection.dart';
import 'quantity_stepper.dart';

/// Actions de collection d'une fiche carte : quantité possédée et wishlist.
///
/// Autonome — la fiche n'a rien à charger elle-même. Le stepper agit sur le
/// lot principal de la carte (lot unique, sinon NM/EN) ; le réglage fin par
/// état et par langue se fait depuis l'onglet Collection.
class CardCollectionActions extends ConsumerStatefulWidget {
  const CardCollectionActions({super.key, required this.card});

  final RiftCard card;

  @override
  ConsumerState<CardCollectionActions> createState() =>
      _CardCollectionActionsState();
}

class _CardCollectionActionsState extends ConsumerState<CardCollectionActions> {
  String? _error;
  bool _busy = false;

  /// Quantité souhaitée après action locale ; null tant qu'on n'a pas touché à
  /// la wishlist (la valeur vient alors de la carte).
  int? _wished;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleWish(bool wished) => _run(() async {
    final api = ref.read(collectionApiProvider);
    if (wished) {
      await api.removeWish(widget.card.id);
    } else {
      await api.setWish(cardId: widget.card.id, qty: 1);
    }
    if (!mounted) return;
    setState(() => _wished = wished ? 0 : 1);
    ref.invalidate(wishlistControllerProvider);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );
    if (!signedIn) {
      return Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Connecte-toi pour suivre ta collection'),
          AdaptiveTextButton(
            label: 'Se connecter',
            onPressed: () =>
                context.go(AppRoutes.loginFrom(AppRoutes.card(widget.card.id))),
          ),
        ],
      );
    }

    final collection = ref.watch(cardCollectionProvider(widget.card.id));
    final state = collection.valueOrNull;
    final owned = state?.totalQty ?? widget.card.ownedQty ?? 0;
    final wished = (_wished ?? widget.card.wishedQty ?? 0) > 0;
    final controller = ref.read(
      cardCollectionProvider(widget.card.id).notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Dans ma collection : $owned',
              style: theme.textTheme.bodyMedium,
            ),
            QuantityStepper(
              value: owned,
              max: maxCollectionQty,
              enabled: !_busy && state != null,
              // Sans lot identifiable (plusieurs états ou langues, aucun NM/EN),
              // le retrait se fait depuis l'onglet Collection.
              canDecrease: state?.mainEntry != null,
              semanticsLabel: 'Exemplaires possédés de ${widget.card.name}',
              onChanged: (value) =>
                  _run(() => controller.adjust(value - owned)),
            ),
            AdaptiveTextButton(
              label: wished ? 'Dans ma wishlist' : 'Ajouter à la wishlist',
              onPressed: _busy ? null : () => _toggleWish(wished),
            ),
          ],
        ),
        if (state != null && state.hasSeveralLots)
          Text(
            '${state.entries.length} lots : ${state.entries.map((entry) => entry.label).join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      ],
    );
  }
}
