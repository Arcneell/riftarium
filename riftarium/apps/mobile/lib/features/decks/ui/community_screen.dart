import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/profile_action.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/decks_controller.dart';
import '../data/decks_api.dart';
import '../domain/deck.dart';
import 'deck_widgets.dart';

/// Tris proposés par l'API (`sort`), dans l'ordre du site.
const List<(String, String)> _sorts = [
  ('likes', 'Tendance'),
  ('views', 'Plus vus'),
  ('recent', 'Récents'),
];

/// Decks publiés par la communauté. Consultable sans compte.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(communityQueryProvider.notifier).setQuery(value.trim());
    });
  }

  Future<void> _toggleLike(CommunityDeck deck) async {
    final signedIn = ref.read(authControllerProvider).isSignedIn;
    if (!signedIn) {
      await showAdaptiveMessage(
        context,
        title: 'Connexion requise',
        message: 'Connecte-toi pour aimer les decks de la communauté.',
      );
      return;
    }
    try {
      await ref.read(deckActionsProvider).toggleLike(deck.id);
    } on ApiException catch (error) {
      if (!mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Action impossible',
        message: error.message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // La page suivante se précharge dès que celle-ci arrive : plus de squelette
    // pendant le défilement.
    ref.listen(communityDecksProvider, (previous, next) {
      final legends = next.valueOrNull?.items
          .map((deck) => deck.legend)
          .nonNulls;
      if (legends != null) precacheCardThumbs(context, legends);
    });

    final page = ref.watch(communityDecksProvider);
    final controller = ref.read(communityQueryProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          PageBanner(
            title: 'Communauté',
            eyebrow: 'Decks partagés',
            art: RiftBanners.community,
            actions: const [ProfileAction()],
          ),
          const DecksSegment(current: DecksTab.community),
          SliverToBoxAdapter(
            child: _Filters(search: _search, onSearchChanged: _onSearchChanged),
          ),
          page.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingView(),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: error is ApiException
                    ? error.message
                    : 'Impossible de charger les decks partagés.',
                onRetry: () => ref.invalidate(communityDecksProvider),
              ),
            ),
            data: (value) => value.items.isEmpty
                ? SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                    sliver: SliverToBoxAdapter(
                      child: InvitePanel(
                        icon: Icons.groups_2_outlined,
                        title: 'Aucun deck partagé',
                        message:
                            'Aucun deck publié ne correspond à ces filtres.',
                        action: GhostButton(
                          label: 'Réinitialiser les filtres',
                          icon: Icons.filter_alt_off_outlined,
                          onPressed: controller.reset,
                        ),
                      ),
                    ),
                  )
                : _DeckList(page: value, onLike: _toggleLike),
          ),
          if (page.valueOrNull case final value?)
            SliverToBoxAdapter(
              child: _Pager(
                page: value.page,
                pageCount: value.pageCount,
                onChanged: controller.setPage,
              ),
            ),
        ],
      ),
    );
  }
}

/// Liste des boîtes de deck, précédée du total.
class _DeckList extends StatelessWidget {
  const _DeckList({required this.page, required this.onLike});

  final CommunityPage page;
  final ValueChanged<CommunityDeck> onLike;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      sliver: SliverList.separated(
        itemCount: page.items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('${page.total} deck(s)', style: text.mono),
            );
          }
          final deck = page.items[index - 1];
          return Reveal(
            index: index - 1,
            child: DeckBox.shared(
              deck: deck,
              onOpen: () => context.go(AppRoutes.deck(deck.id)),
              onLike: () => onLike(deck),
            ),
          );
        },
      ),
    );
  }
}

/// Recherche, tri, légendes, format et domaines : tout en puces.
class _Filters extends ConsumerWidget {
  const _Filters({required this.search, required this.onSearchChanged});

  final TextEditingController search;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(communityQueryProvider).filters;
    final controller = ref.read(communityQueryProvider.notifier);
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          child: TextField(
            controller: search,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Nom, auteur, légende…',
              prefixIcon: Icon(Icons.search, size: 20),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              for (final sort in _sorts) ...[
                ChoicePill(
                  label: sort.$2,
                  selected: filters.sort == sort.$1,
                  onTap: () => controller.setSort(sort.$1),
                ),
                const SizedBox(width: 8),
              ],
              _LegendPill(filters: filters),
              const SizedBox(width: 8),
              _FormatPill(filters: filters),
              const SizedBox(width: 8),
              ChoicePill(
                label: filters.liked ? 'Mes likes' : 'Aimés',
                icon: Icons.favorite_outline,
                selected: filters.liked,
                onTap: controller.toggleLiked,
              ),
              if (signedIn) ...[
                const SizedBox(width: 8),
                ChoicePill(
                  label: 'Constructibles',
                  icon: Icons.inventory_2_outlined,
                  selected: filters.buildable,
                  onTap: controller.toggleBuildable,
                ),
              ],
              if (filters.activeCount > 0) ...[
                const SizedBox(width: 8),
                ChoicePill(
                  label: 'Réinitialiser (${filters.activeCount})',
                  icon: Icons.filter_alt_off_outlined,
                  selected: false,
                  onTap: controller.reset,
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
            children: [
              for (final domain in filterDomains) ...[
                DomainFilterChip(
                  domain: domain,
                  selected: filters.domains.contains(domain),
                  onTap: () => controller.toggleDomain(domain),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Filtre « Légendes » : vignette ronde de la légende choisie, sinon un menu.
class _LegendPill extends ConsumerWidget {
  const _LegendPill({required this.filters});

  final CommunityFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legends = ref.watch(communityLegendsProvider).valueOrNull ?? const [];
    final selected = filters.legends;
    final first = legends.where((l) => selected.contains(l.id)).firstOrNull;
    final label = switch (selected.length) {
      0 => 'Légendes',
      1 => first?.name ?? 'Légendes (1)',
      _ => 'Légendes (${selected.length})',
    };
    return ChoicePill(
      label: label,
      selected: selected.isNotEmpty,
      menu: true,
      leading: first == null ? null : LegendAvatar(legend: first, size: 22),
      onTap: legends.isEmpty ? null : () => _open(context, ref, legends),
    );
  }

  void _open(
    BuildContext context,
    WidgetRef ref,
    List<CommunityLegend> legends,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LegendsSheet(legends: legends),
    );
  }
}

/// Choix multiple des légendes, avec leur vignette ronde.
class _LegendsSheet extends ConsumerWidget {
  const _LegendsSheet({required this.legends});

  final List<CommunityLegend> legends;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final selected = ref.watch(communityQueryProvider).filters.legends;
    final controller = ref.read(communityQueryProvider.notifier);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              eyebrow: 'Filtrer',
              title: 'Légendes',
              padding: EdgeInsets.fromLTRB(18, 4, 18, 8),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: legends.length,
                itemBuilder: (context, index) {
                  final legend = legends[index];
                  final on = selected.contains(legend.id);
                  return ListTile(
                    leading: LegendAvatar(legend: legend, size: 38),
                    title: Text(legend.name, style: text.body),
                    subtitle: Text(
                      '${legend.deckCount} deck(s)',
                      style: text.mono,
                    ),
                    trailing: Icon(
                      on ? Icons.check_circle : Icons.circle_outlined,
                      color: on ? RiftColors.gold : text.muted,
                    ),
                    onTap: () => controller.toggleLegend(legend.id),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: GhostButton(
                label: 'Fermer',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vignette ronde d'une légende du filtre.
class LegendAvatar extends StatelessWidget {
  const LegendAvatar({super.key, required this.legend, this.size = 32});

  final CommunityLegend legend;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = legend.imageUrl;
    final initial = legend.name.isEmpty ? '?' : legend.name[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RiftColors.goldGradient,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url == null || url.isEmpty
          ? Text(
              initial,
              style: TextStyle(
                fontFamily: RiftFonts.display,
                fontSize: size * 0.45,
                color: RiftColors.paper,
              ),
            )
          : CachedNetworkImage(
              imageUrl: cardThumb(url, width: 160),
              cacheManager: riftImageCache,
              fit: BoxFit.cover,
              // Le visuel d'une carte est un portrait : on cadre le buste.
              alignment: Alignment.topCenter,
              width: size,
              height: size,
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
    );
  }
}

/// Filtre « Format » : tous, légal ou illégal.
class _FormatPill extends ConsumerWidget {
  const _FormatPill({required this.filters});

  final CommunityFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(communityQueryProvider.notifier);
    final current = filters.formats.isEmpty ? null : filters.formats.first;
    return PopupMenuButton<String>(
      onSelected: (value) => controller.setFormat(value == '' ? null : value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: '', child: Text('Tous les formats')),
        PopupMenuItem(value: 'tournament', child: Text('Légal')),
        PopupMenuItem(value: 'free', child: Text('Illégal')),
      ],
      child: ChoicePill(
        label: current == null
            ? 'Format'
            : (current == 'free' ? 'Illégal' : 'Légal'),
        selected: current != null,
        menu: true,
      ),
    );
  }
}

/// Pagination : 20 decks par page, comme sur le site.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox(height: 32);
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: page <= 1 ? null : () => onChanged(page - 1),
            child: const Text('Précédent'),
          ),
          Flexible(
            child: Text(
              'page $page / $pageCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.mono,
            ),
          ),
          TextButton(
            onPressed: page >= pageCount ? null : () => onChanged(page + 1),
            child: const Text('Suivant'),
          ),
        ],
      ),
    );
  }
}
