import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/decks_controller.dart';
import '../data/decks_api.dart';
import '../domain/deck.dart';
import 'deck_form_dialogs.dart';
import 'deck_widgets.dart';

/// Tris proposés par l'API (`sort`).
const List<(String, String)> _sorts = [
  ('likes', 'Tendance'),
  ('views', 'Plus vus'),
  ('recent', 'Récents'),
];

const Map<String, String> _domainLabels = {
  'Fury': 'Fureur',
  'Calm': 'Calme',
  'Mind': 'Esprit',
  'Body': 'Corps',
  'Chaos': 'Chaos',
  'Order': 'Ordre',
};

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
    final query = ref.watch(communityQueryProvider);
    final page = ref.watch(communityDecksProvider);
    final controller = ref.read(communityQueryProvider.notifier);
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );

    return AdaptiveScaffold(
      title: 'Decks partagés',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Nom, auteur, légende…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final sort in _sorts) ...[
                  ChoicePill(
                    label: sort.$2,
                    selected: query.filters.sort == sort.$1,
                    onTap: () => controller.setSort(sort.$1),
                  ),
                  const SizedBox(width: 8),
                ],
                _LegendMenu(filters: query.filters),
                const SizedBox(width: 8),
                _DomainMenu(filters: query.filters),
                const SizedBox(width: 8),
                _FormatMenu(filters: query.filters),
                const SizedBox(width: 8),
                ChoicePill(
                  label: 'Aimés',
                  selected: query.filters.liked,
                  onTap: controller.toggleLiked,
                ),
                if (signedIn) ...[
                  const SizedBox(width: 8),
                  ChoicePill(
                    label: 'Constructibles',
                    selected: query.filters.buildable,
                    onTap: controller.toggleBuildable,
                  ),
                ],
                if (query.filters.activeCount > 0) ...[
                  const SizedBox(width: 8),
                  ChoicePill(
                    label: 'Réinitialiser (${query.filters.activeCount})',
                    selected: false,
                    onTap: controller.reset,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: page.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: error is ApiException
                    ? error.message
                    : 'Impossible de charger les decks partagés.',
                onRetry: () => ref.invalidate(communityDecksProvider),
              ),
              data: (value) => value.items.isEmpty
                  ? const EmptyView(
                      title: 'Aucun deck partagé',
                      detail:
                          'Rien ici pour l’instant. Publie le tien depuis '
                          'l’éditeur !',
                      icon: Icons.groups_outlined,
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${value.total} deck(s)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 12),
                            itemCount: value.items.length,
                            itemBuilder: (context, index) {
                              final deck = value.items[index];
                              return CommunityDeckTile(
                                deck: deck,
                                onOpen: () =>
                                    context.go(AppRoutes.deck(deck.id)),
                                onLike: () => _toggleLike(deck),
                              );
                            },
                          ),
                        ),
                        _Pager(
                          page: value.page,
                          pageCount: value.pageCount,
                          onChanged: controller.setPage,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtre « Légendes » alimenté par `GET /api/community/legends`.
class _LegendMenu extends ConsumerWidget {
  const _LegendMenu({required this.filters});

  final CommunityFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legends = ref.watch(communityLegendsProvider).valueOrNull ?? const [];
    final controller = ref.read(communityQueryProvider.notifier);
    final selected = filters.legends;
    final label = selected.isEmpty
        ? 'Légendes'
        : 'Légendes (${selected.length})';
    if (legends.isEmpty) {
      return ChoicePill(label: label, selected: selected.isNotEmpty);
    }
    return PopupMenuButton<String>(
      tooltip: 'Légendes',
      onSelected: controller.toggleLegend,
      itemBuilder: (context) => [
        for (final legend in legends)
          CheckedPopupMenuItem(
            value: legend.id,
            checked: selected.contains(legend.id),
            child: Text('${legend.name} (${legend.deckCount})'),
          ),
      ],
      child: ChoicePill(label: label, selected: selected.isNotEmpty),
    );
  }
}

class _DomainMenu extends ConsumerWidget {
  const _DomainMenu({required this.filters});

  final CommunityFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(communityQueryProvider.notifier);
    final selected = filters.domains;
    return PopupMenuButton<String>(
      tooltip: 'Domaines',
      onSelected: controller.toggleDomain,
      itemBuilder: (context) => [
        for (final entry in _domainLabels.entries)
          CheckedPopupMenuItem(
            value: entry.key,
            checked: selected.contains(entry.key),
            child: Text(entry.value),
          ),
      ],
      child: ChoicePill(
        label: selected.isEmpty ? 'Domaines' : 'Domaines (${selected.length})',
        selected: selected.isNotEmpty,
      ),
    );
  }
}

class _FormatMenu extends ConsumerWidget {
  const _FormatMenu({required this.filters});

  final CommunityFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(communityQueryProvider.notifier);
    final current = filters.formats.isEmpty ? null : filters.formats.first;
    return PopupMenuButton<String>(
      tooltip: 'Format',
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
      ),
    );
  }
}

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
    if (pageCount <= 1) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: page <= 1 ? null : () => onChanged(page - 1),
            child: const Text('← Précédent'),
          ),
          Text('page $page / $pageCount'),
          TextButton(
            onPressed: page >= pageCount ? null : () => onChanged(page + 1),
            child: const Text('Suivant →'),
          ),
        ],
      ),
    );
  }
}
