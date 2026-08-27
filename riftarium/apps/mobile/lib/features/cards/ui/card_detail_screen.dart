import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../../core/config.dart';
import '../../collection/ui/widgets/card_collection_actions.dart';
import '../application/cards_controller.dart';
import '../domain/card.dart';
import '../domain/card_labels.dart';
import '../domain/prices_meta.dart';
import 'widgets/pills.dart';

/// Fiche d'une carte : visuel, caractéristiques, prix et variantes.
class CardDetailScreen extends ConsumerWidget {
  const CardDetailScreen({super.key, required this.cardId});

  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(cardDetailProvider(cardId));
    final card = detail.valueOrNull;
    final Widget body;
    if (card != null) {
      body = _CardSheet(card: card);
    } else if (detail.hasError) {
      final error = detail.error;
      body = ErrorView(
        message: error is ApiException ? error.message : 'Erreur inattendue.',
        onRetry: () => ref.invalidate(cardDetailProvider(cardId)),
      );
    } else {
      body = const LoadingView();
    }
    return AdaptiveScaffold(title: card?.name ?? 'Carte', body: body);
  }
}

class _CardSheet extends ConsumerWidget {
  const _CardSheet({required this.card});

  final RiftCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final imageWidth = card.isLandscape
        ? math.min(screenWidth - 32, 440.0)
        : math.min(screenWidth * 0.62, 300.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Semantics(
                  button: true,
                  label: 'Agrandir le visuel de ${card.name}',
                  child: GestureDetector(
                    onTap: () => _openFullScreen(context, card),
                    child: CardImage(
                      card: card,
                      width: imageWidth,
                      borderRadius: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${card.setId.toUpperCase()} · ${rarityLabel(card.rarity)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(card.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 2),
              Text(
                card.displayCode,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (card.type.isNotEmpty)
                    InfoPill(label: typeLabel(card.type)),
                  if (card.supertype != null && card.supertype!.isNotEmpty)
                    InfoPill(label: card.supertype!, muted: true),
                  if (domainsLabel(card.domains) != null)
                    InfoPill(label: domainsLabel(card.domains)!, muted: true),
                ],
              ),
              const SizedBox(height: 16),
              _StatsRow(card: card),
              if (card.text.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(card.text, style: theme.textTheme.bodyMedium),
              ],
              if (card.flavour != null && card.flavour!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '« ${card.flavour!} »',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
              if (card.artist != null && card.artist!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Illustration : ${card.artist!}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
              if (card.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in card.tags)
                      InfoPill(label: tag, muted: true),
                  ],
                ),
              ],
              _PriceBlock(card: card),

              // Collection et wishlist (quantités, ajout, retrait) : widget
              // autonome, gère aussi l'état déconnecté.
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: CardCollectionActions(card: card),
              ),

              _VariantsCarousel(card: card),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AdaptiveFilledButton(
                  label: 'Ouvrir sur le site',
                  onPressed: () => _openOnWeb(context, card.id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Énergie, puissance et pouvoir, uniquement quand la carte les porte.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.card});

  final RiftCard card;

  @override
  Widget build(BuildContext context) {
    final stats = <(String, String)>[
      if (card.energy != null) ('Énergie', '${card.energy}'),
      if (card.might != null) ('Puissance', '${card.might}'),
      if (card.power != null) ('Pouvoir', '${card.power}'),
    ];
    if (stats.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Wrap(
      spacing: 24,
      runSpacing: 12,
      children: [
        for (final (label, value) in stats)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
      ],
    );
  }
}

/// Prix indicatif en euros, avec la fraîcheur et l'origine des données.
class _PriceBlock extends ConsumerWidget {
  const _PriceBlock({required this.card});

  final RiftCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = card.priceEur;
    if (price == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // Sans méta chargée, la note de repli reste affichée : un prix n'apparaît
    // jamais sans sa mise en garde.
    final meta =
        ref.watch(pricesMetaProvider).valueOrNull ?? const PricesMeta();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prix indicatif',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatEuro(price),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              meta.note,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VariantsCarousel extends ConsumerWidget {
  const _VariantsCarousel({required this.card});

  final RiftCard card;

  static const double _tileWidth = 84;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants = ref.watch(cardVariantsProvider(card.id)).valueOrNull;
    if (variants == null || variants.length < 2) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Variantes', style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          SizedBox(
            height: _tileWidth * 7 / 5 + 24,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: variants.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final variant = variants[index];
                final current = variant.id == card.id;
                return Semantics(
                  button: true,
                  selected: current,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: current
                        ? null
                        : () => context.go(AppRoutes.card(variant.id)),
                    child: SizedBox(
                      width: _tileWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Opacity(
                            opacity: current ? 1 : 0.75,
                            child: CardImage(card: variant, borderRadius: 8),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            variantLabel(variant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: current
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: current
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Visuel plein écran, zoomable et déplaçable.
void _openFullScreen(BuildContext context, RiftCard card) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (context, _, _) => _FullScreenCardImage(card: card),
    ),
  );
}

class _FullScreenCardImage extends StatelessWidget {
  const _FullScreenCardImage({required this.card});

  final RiftCard card;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: CardImage(card: card, borderRadius: 12),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(CupertinoIcons.xmark, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ouvre la fiche du site dans le navigateur.
Future<void> _openOnWeb(BuildContext context, String cardId) async {
  final uri = Uri.parse('${AppConfig.webBaseUrl}/cartes/$cardId');
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (opened || !context.mounted) return;
  await showAdaptiveMessage(
    context,
    title: 'Lien non ouvert',
    message: 'Impossible d’ouvrir $uri sur cet appareil.',
  );
}
