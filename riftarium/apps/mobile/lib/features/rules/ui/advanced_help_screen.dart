import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/profile_action.dart';
import '../application/guides_providers.dart';
import '../domain/guides.dart';
import 'rules_navigation.dart';
import 'widgets/rules_search_field.dart';

/// Aide avancée : toutes les mécaniques, rangées par famille.
///
/// C'est l'écran qu'on ouvre en pleine partie : une recherche, des familles
/// en puces, et une fiche par mécanique.
class AdvancedHelpScreen extends ConsumerStatefulWidget {
  const AdvancedHelpScreen({super.key});

  @override
  ConsumerState<AdvancedHelpScreen> createState() => _AdvancedHelpScreenState();
}

class _AdvancedHelpScreenState extends ConsumerState<AdvancedHelpScreen> {
  static const Duration _debounceDelay = Duration(milliseconds: 200);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _category;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final value = _searchController.text.trim();
    if (value == _query) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final guides = ref.watch(guidesProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PageBanner(
            title: 'Chaque mécanique a sa fiche',
            eyebrow: 'Aide avancée',
            art: RiftBanners.rules,
            expandedHeight: 160,
            leading: RulesBackButton(),
            actions: [ProfileAction()],
          ),
          ...guides.when(
            loading: () => const [
              SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
            ],
            error: (error, stack) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(
                  message: 'Impossible de charger l’aide avancée.',
                  onRetry: () => ref.invalidate(guidesProvider),
                ),
              ),
            ],
            data: _bodySlivers,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }

  List<Widget> _bodySlivers(GuidesDocument document) {
    final searching = _query.length >= kGuideSearchMinLength;
    final matching = searching
        ? ref.watch(guideSearchProvider(_query))
        : document.topics;
    final groups = [
      for (final category in document.categories)
        if (_category == null || _category == category.key)
          (
            category: category,
            topics: [
              for (final topic in matching)
                if (topic.category == category.key) topic,
            ],
          ),
    ].where((group) => group.topics.isNotEmpty).toList(growable: false);

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
        sliver: SliverToBoxAdapter(
          child: RulesSearchField(
            controller: _searchController,
            label: 'Rechercher une mécanique',
            hint: 'tank, conquête, réaction, recycler…',
            onClear: () => setState(() => _query = ''),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            children: [
              _CategoryChip(
                label: 'Tout',
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final category in document.categories)
                _CategoryChip(
                  label: category.label,
                  selected: _category == category.key,
                  onTap: () => setState(
                    () => _category = _category == category.key
                        ? null
                        : category.key,
                  ),
                ),
            ],
          ),
        ),
      ),
      if (groups.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 36, 18, 0),
            child: EmptyView(
              title: 'Aucune mécanique',
              detail:
                  'Rien ne correspond à cette recherche. Le texte officiel, '
                  'lui, est intégral.',
              icon: Icons.search_off_outlined,
              action: GhostButton(
                label: 'Ouvrir les règles officielles',
                onPressed: () => context.go(AppRoutes.officialRules),
              ),
            ),
          ),
        )
      else
        for (final group in groups) ...[
          SliverToBoxAdapter(
            child: SectionTitle(
              title: group.category.label,
              trailing: Text(
                '${group.topics.length}',
                style: riftText(context).mono,
              ),
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverList.separated(
              itemCount: group.topics.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final topic = group.topics[index];
                return Reveal(
                  index: index,
                  child: _TopicRow(
                    topic: topic,
                    onTap: () =>
                        context.go(AppRoutes.advancedTopic(topic.slug)),
                  ),
                );
              },
            ),
          ),
        ],
    ];
  }
}

/// Puce de famille (« Combat », « Mots-clés ») : filtre la liste.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? RiftColors.gold.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(RiftRadius.full),
            border: Border.all(
              color: selected
                  ? RiftColors.gold
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Text(
            label,
            style: text.small.copyWith(
              fontSize: 13.5,
              fontVariations: RiftFonts.weight(selected ? 600 : 400),
              color: selected ? RiftColors.goldDeep : text.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Une mécanique dans la liste : titre Marcellus et résumé.
class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.onTap});

  final GuideTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.title, style: text.displaySmall),
                const SizedBox(height: 4),
                Text(topic.summary, style: text.small),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
  }
}
