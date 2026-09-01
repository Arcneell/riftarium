import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/wishlist_controller.dart';
import '../domain/collection.dart';
import 'collection_screen.dart' show messageOf;
import 'widgets/collection_sign_in.dart';
import 'widgets/quantity_stepper.dart';

/// Liste de souhaits : bannière basse, total et valeur, puis une ligne par
/// carte convoitée — vignette, prix, quantité visée, retrait par glissement.
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
      return const CollectionSignIn(
        title: 'Wishlist',
        eyebrow: 'Mes envies',
        message: 'Connecte-toi pour suivre les cartes qu’il te manque.',
        returnTo: AppRoutes.wishlist,
        expandedHeight: 160,
      );
    }

    final wishlist = ref.watch(wishlistControllerProvider);
    final data = wishlist.valueOrNull;
    final controller = ref.read(wishlistControllerProvider.notifier);
    final text = riftText(context);

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: controller.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            PageBanner(
              title: 'Wishlist',
              eyebrow: 'Mes envies',
              art: RiftBanners.collection,
              expandedHeight: 160,
              leading: const BackButton(),
            ),
            if (data == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: wishlist.hasError
                    ? ErrorView(
                        message: messageOf(wishlist.error),
                        onRetry: controller.refresh,
                      )
                    : const LoadingView(),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Stat(
                          index: 0,
                          label: 'Cartes souhaitées',
                          value: '${data.total}',
                        ),
                        const SizedBox(width: 10),
                        _Stat(
                          index: 1,
                          label: 'Valeur estimée',
                          value: formatEur(data.valueEur) ?? '—',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_error != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _error!,
                      style: text.small.copyWith(color: RiftColors.fury),
                    ),
                  ),
                ),
              if (data.items.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 32, 18, 24),
                    child: EmptyView(
                      title: 'Ta wishlist est vide',
                      icon: Icons.favorite_border,
                      action: GoldButton(
                        label: 'Parcourir les cartes',
                        icon: Icons.style_outlined,
                        expand: false,
                        onPressed: () => context.go(AppRoutes.cards),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  sliver: SliverList.separated(
                    itemCount: data.items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = data.items[index];
                      return _WishRow(
                        item: item,
                        index: index,
                        busy: _busyCardId == item.card.id,
                        onQty: (qty) => _run(
                          item.card.id,
                          () => controller.setQuantity(
                            cardId: item.card.id,
                            qty: qty,
                          ),
                        ),
                        onRemove: () => _run(
                          item.card.id,
                          () => controller.remove(item.card.id),
                        ),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.index, required this.label, required this.value});

  final int index;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Expanded(
      child: Reveal(
        index: index,
        child: RiftPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: text.displayMedium.copyWith(
                    fontSize: 22,
                    color: RiftColors.gold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                style: text.eyebrow.copyWith(color: text.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une envie : vignette 64 px, nom Marcellus, code et prix en mono, stepper
/// compact. Le glissement vers la gauche retire la carte.
class _WishRow extends StatelessWidget {
  const _WishRow({
    required this.item,
    required this.index,
    required this.busy,
    required this.onQty,
    required this.onRemove,
  });

  final WishItem item;
  final int index;
  final bool busy;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final price = formatEur(item.valueEur);
    return Reveal(
      index: index,
      child: Dismissible(
        key: ValueKey(item.card.id),
        direction: busy ? DismissDirection.none : DismissDirection.endToStart,
        onDismissed: (_) => onRemove(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: RiftColors.fury.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(RiftRadius.md),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: RiftPanel(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PressScale(
                onTap: () => context.go(AppRoutes.card(item.card.id)),
                child: CardImage(
                  card: item.card,
                  width: 64,
                  heroTag: 'wish-${item.card.id}',
                  shadow: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.card.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.displaySmall.copyWith(fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price == null
                          ? item.card.displayCode
                          : '${item.card.displayCode} · $price',
                      style: text.mono,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        QuantityStepper(
                          value: item.qty,
                          min: 1,
                          max: maxWishQty,
                          enabled: !busy,
                          size: StepperSize.compact,
                          semanticsLabel:
                              'Quantité souhaitée de ${item.card.name}',
                          onChanged: onQty,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: busy ? null : onRemove,
                          tooltip: 'Retirer',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: RiftColors.fury,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
