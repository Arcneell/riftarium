import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/profile_action.dart';
import '../../../core/api_exception.dart';
import '../../../core/config.dart';
import '../../collection/ui/widgets/card_collection_actions.dart';
import '../application/cards_controller.dart';
import '../domain/card.dart';
import '../domain/card_labels.dart';
import '../domain/prices_meta.dart';
import 'widgets/card_text_view.dart';

/// Fiche d'une carte : on l'ouvre sur son visuel, posé dans la lueur de son
/// domaine ; les caractéristiques se déroulent dessous.
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

    return Scaffold(
      body: _DetailChrome(
        body: body,
        onBack: () =>
            context.canPop() ? context.pop() : context.go(AppRoutes.cards),
      ),
    );
  }
}

/// Retour et profil posés sur le visuel. Tant que le visuel est à l'écran,
/// rien ne le coupe ; dès qu'il a défilé, le bandeau devient opaque pour ne
/// plus flotter sur le titre et les caractéristiques.
class _DetailChrome extends StatefulWidget {
  const _DetailChrome({required this.body, required this.onBack});

  final Widget body;
  final VoidCallback onBack;

  @override
  State<_DetailChrome> createState() => _DetailChromeState();
}

class _DetailChromeState extends State<_DetailChrome> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final scrolled = notification.metrics.pixels > 56;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paper = theme.scaffoldBackgroundColor;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      // `expand` : sans lui, le Stack prendrait la hauteur de la rangée
      // d'actions (seul enfant non positionné) et rognerait la fiche.
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: widget.body),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: RiftMotion.quick,
              decoration: BoxDecoration(
                color: _scrolled
                    ? paper.withValues(alpha: 0.96)
                    : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: _scrolled
                        ? theme.colorScheme.outline
                        : Colors.transparent,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                  child: Row(
                    children: [
                      _OverlayAction(
                        icon: Icons.arrow_back,
                        label: 'Revenir à la cartothèque',
                        onTap: widget.onBack,
                      ),
                      const Spacer(),
                      const ProfileAction(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rond translucide des actions posées sur le visuel.
class _OverlayAction extends StatelessWidget {
  const _OverlayAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final paper = Theme.of(context).scaffoldBackgroundColor;
    return Semantics(
      button: true,
      label: label,
      child: PressScale(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: paper.withValues(alpha: 0.82),
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            boxShadow: RiftShadows.soft,
          ),
          child: Icon(icon, size: 20, color: text.ink),
        ),
      ),
    );
  }
}

class _CardSheet extends ConsumerWidget {
  const _CardSheet({required this.card});

  final RiftCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final meta = [
      if (card.type.isNotEmpty) typeLabel(card.type),
      if (card.rarity.isNotEmpty) rarityLabel(card.rarity),
      if (card.setId.isNotEmpty) card.setId.toUpperCase(),
    ].join(' · ');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardStage(card: card),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Reveal(
                      index: 0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              MonoBadge(label: card.displayCode),
                              if (card.supertype != null &&
                                  card.supertype!.isNotEmpty)
                                MonoBadge(label: card.supertype!),
                              for (final domain in card.domains)
                                DomainChip(domain: domain),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            card.name,
                            style: text.displayMedium.copyWith(fontSize: 26),
                          ),
                          const SizedBox(height: 6),
                          Text(meta, style: text.small),
                          const SizedBox(height: 12),
                          const GoldRule(),
                        ],
                      ),
                    ),
                    if (card.energy != null ||
                        card.might != null ||
                        card.power != null)
                      _Block(index: 1, child: _StatsRow(card: card)),
                    if (card.text.isNotEmpty)
                      _Block(
                        index: 2,
                        child: RiftPanel(child: CardTextView(text: card.text)),
                      ),
                    if (card.flavour != null && card.flavour!.isNotEmpty)
                      _Block(
                        index: 3,
                        child: Text(
                          '« ${card.flavour!} »',
                          style: text.small.copyWith(
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (card.artist != null && card.artist!.isNotEmpty)
                      _Block(
                        index: 4,
                        child: Text(
                          'Illustration : ${card.artist!}',
                          style: text.small,
                        ),
                      ),
                    if (card.tags.isNotEmpty)
                      _Block(
                        index: 5,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tag in card.tags) MonoBadge(label: tag),
                          ],
                        ),
                      ),
                    if (card.priceEur != null)
                      _Block(index: 6, child: _PriceBlock(card: card)),

                    // Collection et wishlist (quantités, ajout, retrait) :
                    // widget autonome, gère aussi l'état déconnecté.
                    _Block(index: 7, child: CardCollectionActions(card: card)),

                    _VariantsCarousel(card: card),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: GhostButton(
                        label: 'Ouvrir sur le site',
                        icon: Icons.open_in_new,
                        onPressed: () => _openOnWeb(context, card.id),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un bloc de la fiche : révélation en cascade et respiration au-dessus.
class _Block extends StatelessWidget {
  const _Block({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Reveal(
      index: index,
      child: Padding(padding: const EdgeInsets.only(top: 18), child: child),
    );
  }
}

/// Le visuel, posé dans la lueur du domaine de la carte.
class _CardStage extends StatelessWidget {
  const _CardStage({required this.card});

  final RiftCard card;

  @override
  Widget build(BuildContext context) {
    final paper = Theme.of(context).scaffoldBackgroundColor;
    final glow = RiftColors.domain(
      card.domains.isEmpty ? '' : card.domains.first,
    );

    return LayoutBuilder(
      builder: (context, constraints) => _stage(
        context,
        paper,
        glow,
        card.isLandscape
            ? math.min(constraints.maxWidth - 36, 460.0)
            : math.min(constraints.maxWidth * 0.64, 300.0),
      ),
    );
  }

  Widget _stage(BuildContext context, Color paper, Color glow, double width) {
    // Seules les impressions foil reflètent ; pas de reflet du tout quand le
    // système demande moins d'animations.
    final shine = card.foil && !MediaQuery.disableAnimationsOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 0.95,
          colors: [
            glow.withValues(alpha: 0.34),
            glow.withValues(alpha: 0.10),
            paper,
          ],
          stops: const [0, 0.58, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 56,
          bottom: 8,
        ),
        child: Center(
          child: Semantics(
            button: true,
            label: 'Agrandir le visuel de ${card.name}',
            child: PressScale(
              onTap: () => _openFullScreen(context, card),
              child: CardImage(
                card: card,
                width: width,
                borderRadius: 14,
                heroTag: 'card-${card.id}',
                thumbWidth: CardArtSize.detail,
                shadow: true,
                foil: shine,
                foilIntensity: card.foil ? 1 : 0.6,
              ),
            ),
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
    final text = riftText(context);

    return Row(
      children: [
        for (final (index, (label, value)) in stats.indexed) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(
            child: RiftPanel(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(
                    value,
                    style: text.displayMedium.copyWith(
                      fontSize: 24,
                      color: RiftColors.gold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.eyebrow.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    final text = riftText(context);
    // Sans méta chargée, la note de repli reste affichée : un prix n'apparaît
    // jamais sans sa mise en garde.
    final meta =
        ref.watch(pricesMetaProvider).valueOrNull ?? const PricesMeta();

    return RiftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prix indicatif'.toUpperCase(), style: text.eyebrow),
          const SizedBox(height: 4),
          Text(
            formatEuro(price),
            style: text.displayMedium.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(meta.note, style: text.small.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Autres impressions de la même carte (alt-art, signature, overnumbered).
class _VariantsCarousel extends ConsumerWidget {
  const _VariantsCarousel({required this.card});

  final RiftCard card;

  static const double _tileWidth = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variants = ref.watch(cardVariantsProvider(card.id)).valueOrNull;
    if (variants == null || variants.length < 2) {
      return const SizedBox.shrink();
    }
    final text = riftText(context);
    // Le reflet de l'impression courante ne tourne pas en mouvement réduit.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          eyebrow: 'Autres impressions',
          title: 'Variantes',
          padding: EdgeInsets.fromLTRB(0, 26, 0, 12),
        ),
        SizedBox(
          height: _tileWidth / CardImage.portraitRatio + 26,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: variants.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final variant = variants[index];
              final current = variant.id == card.id;
              return Reveal(
                index: index,
                child: Semantics(
                  button: true,
                  selected: current,
                  child: PressScale(
                    onTap: current
                        ? null
                        : () => context.go(AppRoutes.card(variant.id)),
                    child: SizedBox(
                      width: _tileWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Opacity(
                            opacity: current ? 1 : 0.7,
                            child: CardImage(
                              card: variant,
                              borderRadius: 8,
                              foil: current && !reduceMotion,
                              foilIntensity: 0.6,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            variantLabel(variant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: text.mono.copyWith(
                              fontSize: 11,
                              color: current ? RiftColors.goldDeep : text.muted,
                              fontWeight: current
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Visuel plein écran, zoomable ; un glissement vers le bas referme.
void _openFullScreen(BuildContext context, RiftCard card) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: RiftColors.inkStrong,
      transitionDuration: RiftMotion.base,
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: _FullScreenCardImage(card: card),
      ),
    ),
  );
}

class _FullScreenCardImage extends StatefulWidget {
  const _FullScreenCardImage({required this.card});

  final RiftCard card;

  @override
  State<_FullScreenCardImage> createState() => _FullScreenCardImageState();
}

class _FullScreenCardImageState extends State<_FullScreenCardImage> {
  final TransformationController _zoom = TransformationController();
  double _drag = 0;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(_onZoom);
  }

  @override
  void dispose() {
    _zoom.removeListener(_onZoom);
    _zoom.dispose();
    super.dispose();
  }

  void _onZoom() {
    final zoomed = _zoom.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _drag = math.max(0, _drag + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) {
    if (_drag > 110 || details.velocity.pixelsPerSecond.dy > 700) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final fade = (1 - _drag / 320).clamp(0.4, 1.0);
    return Material(
      color: RiftColors.inkStrong.withValues(alpha: fade),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _zoomed ? null : _onDragUpdate,
              onVerticalDragEnd: _zoomed ? null : _onDragEnd,
              child: Transform.translate(
                offset: Offset(0, _drag),
                child: InteractiveViewer(
                  transformationController: _zoom,
                  panEnabled: _zoomed,
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: CardImage(
                        card: widget.card,
                        borderRadius: 12,
                        thumbWidth: CardArtSize.zoom,
                      ),
                    ),
                  ),
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
                icon: const Icon(Icons.close, color: Colors.white),
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
