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
import '../application/rules_providers.dart';
import '../domain/guides.dart';
import '../domain/rules.dart';
import 'rule_section_screen.dart';
import 'rules_navigation.dart';
import 'widgets/rules_search_field.dart';

/// Hub des règles : trois paliers, du plus guidé au plus littéral.
///
/// Ce qui compte d'abord, ce sont les guides — le pas à pas du débutant et
/// les fiches de mécaniques avec leurs cas concrets. Le texte officiel reste
/// accessible, en dernier recours.
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
  static const Duration _debounceDelay = Duration(milliseconds: 250);

  /// Sujets les plus consultés : les questions qui reviennent à chaque table.
  static const List<String> _frequentSlugs = [
    'deroulement-du-tour',
    'etapes-du-combat',
    'conquete-et-occupation',
    'la-chaine',
    'energie-et-essence',
    'regle-d-or',
  ];

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

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
    final guides = ref.watch(guidesProvider).valueOrNull;
    final rules = ref.watch(rulesProvider).valueOrNull;
    final searching = _query.length >= kGuideSearchMinLength;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          PageBanner(
            title: 'Règles',
            art: RiftBanners.rules,
            actions: [ProfileAction()],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
            sliver: SliverToBoxAdapter(
              child: RulesSearchField(
                controller: _searchController,
                label: 'Rechercher dans les règles',
                hint: 'tank, conquête, réaction, 002…',
                onClear: () => setState(() => _query = ''),
              ),
            ),
          ),
          if (searching)
            ..._searchSlivers()
          else
            ..._tierSlivers(guides, rules),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- paliers

  List<Widget> _tierSlivers(GuidesDocument? guides, RulesDocument? rules) {
    final topics = guides?.topics.length ?? 0;
    final core = rules?.core?.ruleCount ?? 0;
    final tournament = rules?.tournament?.ruleCount ?? 0;
    final frequent = _frequentTopics(guides);

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
        sliver: SliverList.list(
          children: [
            Reveal(
              index: 0,
              child: _TierPanel(
                step: 1,
                accent: RiftColors.gold,
                kicker: 'En pleine partie',
                title: 'Aide avancée',
                meta: topics == 0 ? null : '$topics mécaniques',
                action: 'Chercher une mécanique',
                big: true,
                onTap: () => context.go(AppRoutes.advancedHelp),
              ),
            ),
            const SizedBox(height: 12),
            Reveal(
              index: 1,
              child: _TierPanel(
                step: 2,
                // Parchemin doré sur la nuit : le dernier recours reste sobre.
                accent: RiftColors.goldSoft,
                kicker: 'Dernier recours',
                title: 'Règles officielles',
                meta: core == 0
                    ? null
                    : '${formatRuleCount(core)} + '
                          '${formatRuleCount(tournament)} règles',
                action: 'Ouvrir le texte intégral',
                onTap: () => context.go(AppRoutes.officialRules),
              ),
            ),
          ],
        ),
      ),
      if (frequent.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: SectionTitle(title: 'Sujets fréquents'),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: Reveal(
              index: 3,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in frequent)
                    _TopicPill(
                      label: topic.title,
                      onTap: () =>
                          context.go(AppRoutes.advancedTopic(topic.slug)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
        sliver: SliverToBoxAdapter(
          child: Reveal(index: 4, child: const _GoldenRule()),
        ),
      ),
    ];
  }

  List<GuideTopic> _frequentTopics(GuidesDocument? guides) {
    if (guides == null) return const [];
    final picked = <GuideTopic>[
      for (final slug in _frequentSlugs) ?guides.topicBySlug(slug),
    ];
    // Fichier plus court (ou renommé) : on complète avec le début de la liste.
    for (final topic in guides.topics) {
      if (picked.length >= 6) break;
      if (!picked.contains(topic)) picked.add(topic);
    }
    return picked.take(6).toList(growable: false);
  }

  // -------------------------------------------------------------- recherche

  List<Widget> _searchSlivers() {
    final topics = ref.watch(guideSearchProvider(_query));
    final hits = ref.watch(ruleSearchProvider(_query));
    final shown = hits.take(6).toList(growable: false);

    if (topics.isEmpty && hits.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 36, 18, 0),
            child: EmptyView(
              title: 'Rien pour « $_query »',
              detail:
                  'Essaie un autre mot, ou ouvre l’aide avancée pour '
                  'parcourir les mécaniques.',
              icon: Icons.search_off_outlined,
              action: GhostButton(
                label: 'Ouvrir l’aide avancée',
                onPressed: () => context.go(AppRoutes.advancedHelp),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      if (topics.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: SectionTitle(
            eyebrow: 'D’abord',
            title: 'Guides',
            trailing: Text('${topics.length}', style: riftText(context).mono),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverList.separated(
            itemCount: topics.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final topic = topics[index];
              return Reveal(
                index: index,
                child: _TopicResult(
                  topic: topic,
                  onTap: () => context.go(AppRoutes.advancedTopic(topic.slug)),
                ),
              );
            },
          ),
        ),
      ],
      if (shown.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: SectionTitle(
            eyebrow: 'Si besoin',
            title: 'Texte officiel',
            trailing: Text('${hits.length}', style: riftText(context).mono),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverList.separated(
            itemCount: shown.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => Reveal(
              index: index,
              child: _RuleResult(hit: shown[index]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          sliver: SliverToBoxAdapter(
            child: GhostButton(
              label: hits.length > shown.length
                  ? 'Voir les ${hits.length} règles'
                  : 'Ouvrir le texte officiel',
              onPressed: () => context.go(AppRoutes.officialRules),
            ),
          ),
        ),
      ],
    ];
  }
}

/// Un palier du hub : numéro, sur-titre, titre Marcellus, promesse, chiffre.
class _TierPanel extends StatelessWidget {
  const _TierPanel({
    required this.step,
    required this.accent,
    required this.kicker,
    required this.title,
    required this.action,
    required this.onTap,
    this.meta,
    this.big = false,
  });

  final int step;
  final Color accent;
  final String kicker;
  final String title;
  final String action;
  final VoidCallback onTap;
  final String? meta;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final styles = riftText(context);
    return RiftPanel(
      raised: true,
      onTap: onTap,
      padding: EdgeInsets.fromLTRB(16, big ? 20 : 16, 16, big ? 20 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: big ? 96 : 76,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$step',
                      style: styles.mono.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(kicker.toUpperCase(), style: styles.eyebrow),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: big
                      ? styles.displayMedium
                      : styles.displayMedium.copyWith(fontSize: 22),
                ),
                if (meta != null) ...[
                  const SizedBox(height: 10),
                  MonoBadge(label: meta!, color: accent),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      action,
                      style: styles.bodyStrong.copyWith(
                        fontSize: 14.5,
                        color: RiftColors.calmText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.arrow_forward,
                      size: 15,
                      color: RiftColors.calmText,
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

/// Puce d'un sujet fréquent.
class _TopicPill extends StatelessWidget {
  const _TopicPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: RiftColors.hex.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(RiftRadius.full),
          border: Border.all(color: RiftColors.hex.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          style: text.bodyStrong.copyWith(fontSize: 14, color: text.ink),
        ),
      ),
    );
  }
}

/// Résultat « guide » : titre et résumé.
class _TopicResult extends StatelessWidget {
  const _TopicResult({required this.topic, required this.onTap});

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
                Text(
                  topic.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.small,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
  }
}

/// Résultat « texte officiel » : numéro et extrait.
class _RuleResult extends StatelessWidget {
  const _RuleResult({required this.hit});

  final RuleSearchHit hit;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      onTap: () => openRuleLocation(
        context,
        RuleLocation(
          book: hit.book,
          chapter: hit.chapter,
          section: hit.section,
          entry: hit.entry,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MonoBadge(label: hit.entry.number),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hit.section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.small.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hit.snippet,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: text.body.copyWith(fontSize: 14.5),
          ),
        ],
      ),
    );
  }
}

/// La règle d'or, rappelée sous les paliers : elle tranche la moitié des
/// questions de table.
class _GoldenRule extends StatelessWidget {
  const _GoldenRule();

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Règle 002 — La Règle d’or'.toUpperCase(), style: text.eyebrow),
          const SizedBox(height: 8),
          const GoldRule(),
          const SizedBox(height: 10),
          Text(
            '« Ce qui est inscrit sur une carte a priorité sur ce qui est '
            'inscrit dans les règles du jeu. »',
            style: text.displaySmall.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
