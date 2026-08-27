import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design/components.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../core/api_exception.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cards/domain/card.dart';
import '../../application/card_collection_controller.dart';
import '../../application/wishlist_controller.dart';
import '../../data/collection_api.dart';
import '../../domain/collection.dart';
import 'quantity_stepper.dart';

/// Actions de collection d'une fiche carte : quantité possédée et wishlist,
/// dans un panneau parchemin où le nombre d'exemplaires est le chiffre
/// principal.
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
    final text = riftText(context);
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );
    if (!signedIn) {
      return RiftPanel(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Connecte-toi pour suivre ta collection',
                style: text.small,
              ),
            ),
            TextButton(
              onPressed: () => context.go(
                AppRoutes.loginFrom(AppRoutes.card(widget.card.id)),
              ),
              child: const Text('Se connecter'),
            ),
          ],
        ),
      );
    }

    final collection = ref.watch(cardCollectionProvider(widget.card.id));
    final state = collection.valueOrNull;
    final owned = state?.totalQty ?? widget.card.ownedQty ?? 0;
    final wished = (_wished ?? widget.card.wishedQty ?? 0) > 0;
    final controller = ref.read(
      cardCollectionProvider(widget.card.id).notifier,
    );

    return RiftPanel(
      raised: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MA COLLECTION', style: text.eyebrow),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  owned == 0
                      ? 'Aucun exemplaire'
                      : '$owned exemplaire${owned > 1 ? 's' : ''}',
                  style: text.small,
                ),
              ),
              QuantityStepper(
                value: owned,
                max: maxCollectionQty,
                enabled: !_busy && state != null,
                size: StepperSize.large,
                // Sans lot identifiable (plusieurs états ou langues, aucun
                // NM/EN), le retrait se fait depuis l'onglet Collection.
                canDecrease: state?.mainEntry != null,
                semanticsLabel: 'Exemplaires possédés de ${widget.card.name}',
                onChanged: (value) =>
                    _run(() => controller.adjust(value - owned)),
              ),
            ],
          ),
          if (state != null && state.hasSeveralLots) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in state.entries)
                  MonoBadge(label: entry.label),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _WishButton(
            wished: wished,
            enabled: !_busy,
            onPressed: () => _toggleWish(wished),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: text.small.copyWith(color: RiftColors.fury)),
          ],
        ],
      ),
    );
  }
}

/// Bouton secondaire (même habillage que [GhostButton]) dont le cœur se
/// remplit d'un fondu quand la carte entre dans la wishlist.
class _WishButton extends StatelessWidget {
  const _WishButton({
    required this.wished,
    required this.enabled,
    required this.onPressed,
  });

  final bool wished;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: AnimatedSwitcher(
        duration: RiftMotion.base,
        transitionBuilder: (child, animation) =>
            ScaleTransition(scale: animation, child: child),
        child: Icon(
          wished ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(wished),
          size: 18,
          color: wished ? RiftColors.fury : null,
        ),
      ),
      label: Text(wished ? 'Dans ma wishlist' : 'Ajouter à la wishlist'),
    );
  }
}
