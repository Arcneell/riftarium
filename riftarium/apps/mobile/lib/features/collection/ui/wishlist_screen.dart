import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/wishlist_controller.dart';
import '../domain/collection.dart';
import 'collection_screen.dart' show messageOf;
import 'widgets/quantity_stepper.dart';

/// Liste de souhaits : quantité visée, retrait, valeur estimée du total.
class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  String? _error;
  String? _busyCardId;

  Future<void> _run(String cardId, Future<void> Function() action) async {
    if (_busyCardId != null) return;
    setState(() {
      _busyCardId = cardId;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busyCardId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );
    if (!signedIn) {
      return const SignInRequired(
        title: 'Wishlist',
        message: 'Connecte-toi pour noter les cartes qu’il te manque.',
      );
    }

    final wishlist = ref.watch(wishlistControllerProvider);
    final data = wishlist.valueOrNull;
    final controller = ref.read(wishlistControllerProvider.notifier);
    Widget body;
    if (data == null) {
      body = wishlist.hasError
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 48),
              children: [
                ErrorView(
                  message: messageOf(wishlist.error),
                  onRetry: controller.refresh,
                ),
              ],
            )
          : const LoadingView();
    } else {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Cartes souhaitées',
                  value: '${data.total}',
                ),
              ),
              Expanded(
                child: _Stat(
                  label: 'Valeur estimée',
                  value: formatEur(data.valueEur) ?? '—',
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          if (data.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: EmptyView(
                title: 'Ta wishlist est vide',
                detail:
                    'Croise une carte qui te manque dans la cartothèque et ajoute-la depuis sa fiche.',
                icon: Icons.favorite_border,
                action: AdaptiveTextButton(
                  label: 'Parcourir les cartes',
                  onPressed: () => context.go(AppRoutes.cards),
                ),
              ),
            )
          else
            for (final item in data.items)
              _WishRow(
                item: item,
                busy: _busyCardId == item.card.id,
                onQty: (qty) => _run(
                  item.card.id,
                  () => controller.setQuantity(cardId: item.card.id, qty: qty),
                ),
                onRemove: () =>
                    _run(item.card.id, () => controller.remove(item.card.id)),
              ),
        ],
      );
    }

    return AdaptiveScaffold(
      title: 'Wishlist',
      body: RefreshIndicator.adaptive(
        onRefresh: controller.refresh,
        child: body,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _WishRow extends StatelessWidget {
  const _WishRow({
    required this.item,
    required this.busy,
    required this.onQty,
    required this.onRemove,
  });

  final WishItem item;
  final bool busy;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = formatEur(item.valueEur);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.go(AppRoutes.card(item.card.id)),
            child: CardImage(card: item.card, width: 56),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.go(AppRoutes.card(item.card.id)),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.card.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        price == null
                            ? item.card.displayCode
                            : '${item.card.displayCode} · $price',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    QuantityStepper(
                      value: item.qty,
                      min: 1,
                      max: maxWishQty,
                      enabled: !busy,
                      semanticsLabel: 'Quantité souhaitée de ${item.card.name}',
                      onChanged: onQty,
                    ),
                    AdaptiveTextButton(
                      label: 'Retirer',
                      onPressed: busy ? null : onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
