import 'package:cached_network_image/cached_network_image.dart';
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
import '../application/guides_providers.dart';
import '../application/rules_providers.dart';
import '../domain/guides.dart';
import '../domain/rules.dart';
import 'rule_entry_view.dart';
import 'rule_rich_text.dart';
import 'rule_section_screen.dart';
import 'rules_navigation.dart';
import 'widgets/card_zoom.dart';
import 'widgets/topic_demo.dart';

/// Fiche d'une mécanique : l'essentiel d'abord, une démo, des cas concrets,
/// des cartes d'exemple, et le texte officiel replié en bas — dans cet ordre,
/// parce qu'on ouvre cette page au milieu d'une partie.
class AdvancedTopicScreen extends ConsumerWidget {
  const AdvancedTopicScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guides = ref.watch(guidesProvider);
    return Scaffold(
      body: guides.when(
        loading: () => const _Frame(
          title: 'Mécanique',
          eyebrow: 'Aide avancée',
          child: SliverFillRemaining(
            hasScrollBody: false,
            child: LoadingView(),
          ),
        ),
        error: (error, stack) => _Frame(
          title: 'Mécanique',
          eyebrow: 'Aide avancée',
          child: SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              message: 'Impossible de charger cette mécanique.',
              onRetry: () => ref.invalidate(guidesProvider),
            ),
          ),
        ),
        data: (document) {
          final topic = document.topicBySlug(slug);
          if (topic == null) {
            return _Frame(
              title: 'Sujet introuvable',
              eyebrow: 'Aide avancée',
              child: SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyView(
                  title: 'Sujet introuvable',
                  detail: 'Cette mécanique n’existe pas (ou plus).',
                  action: GhostButton(
                    label: 'Toute l’aide avancée',
                    onPressed: () => context.go(AppRoutes.advancedHelp),
                  ),
                ),
              ),
            );
          }
          return _Frame(
            title: topic.title,
            eyebrow: document.categoryLabel(topic.category),
            child: _TopicBody(topic: topic, document: document),
          );
        },
      ),
    );
  }
}

/// Bannière commune aux trois états de l'écran.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.title,
    required this.eyebrow,
    required this.child,
  });

  final String title;
  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        PageBanner(
          title: title,
          eyebrow: eyebrow.isEmpty ? 'Aide avancée' : eyebrow,
          art: RiftBanners.rules,
          expandedHeight: 220,
          leading: const RulesBackButton(fallback: AppRoutes.advancedHelp),
        ),
        child,
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _TopicBody extends StatelessWidget {
  const _TopicBody({required this.topic, required this.document});

  final GuideTopic topic;
  final GuidesDocument document;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final next = document.topicAfter(topic.slug);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      sliver: SliverList.list(
        children: [
          if (topic.chips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final chip in topic.chips) _KeywordBadge(label: chip),
                ],
              ),
            ),
          Text(topic.summary, style: text.body.copyWith(fontSize: 16.5)),
          const SizedBox(height: 6),
          const _PartTitle('L’essentiel'),
          for (final detail in topic.details)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: RiftColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: RuleRichText(detail)),
                ],
              ),
            ),
          if (topic.demo != null) ...[
            const _PartTitle('En images'),
            TopicDemoView(demo: topic.demo!),
          ],
          if (topic.cases.isNotEmpty) ...[
            const _PartTitle('Cas concrets'),
            for (final (index, item) in topic.cases.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Reveal(
                  index: index,
                  child: _CaseTile(item: item),
                ),
              ),
          ],
          if (topic.examples.isNotEmpty) ...[
            const _PartTitle('Cartes d’exemple'),
            _Examples(cards: topic.examples),
          ],
          if (topic.sections.isNotEmpty) ...[
            const _PartTitle('Le texte officiel'),
            _OfficialSections(sections: topic.sections),
          ],
          const SizedBox(height: 26),
          if (next != null) ...[
            Text('Ensuite : ${next.title}', style: text.small),
            const SizedBox(height: 8),
            GoldButton(
              label: 'Sujet suivant',
              icon: Icons.arrow_forward,
              onPressed: () => context.go(AppRoutes.advancedTopic(next.slug)),
            ),
          ],
          const SizedBox(height: 10),
          GhostButton(
            label: 'Toute l’aide avancée',
            onPressed: () => context.go(AppRoutes.advancedHelp),
          ),
        ],
      ),
    );
  }
}

/// Titre de partie à l'intérieur de la fiche.
class _PartTitle extends StatelessWidget {
  const _PartTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.displayMedium.copyWith(fontSize: 21)),
          const SizedBox(height: 8),
          const GoldRule(),
        ],
      ),
    );
  }
}

/// Mot-clé de l'en-tête, coloré comme sur les cartes.
class _KeywordBadge extends StatelessWidget {
  const _KeywordBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = keywordColor(keywordFamily(label));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: RiftFonts.body,
          fontVariations: RiftFonts.weight(700),
          fontStyle: FontStyle.italic,
          fontSize: 12.5,
          letterSpacing: 0.6,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Cas concret : la question en Marcellus, la réponse au dépliage.
class _CaseTile extends StatefulWidget {
  const _CaseTile({required this.item});

  final TopicCase item;

  @override
  State<_CaseTile> createState() => _CaseTileState();
}

class _CaseTileState extends State<_CaseTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RuleRichText(
                  widget.item.question,
                  style: text.displaySmall.copyWith(fontSize: 17, height: 1.35),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: RiftMotion.quick,
                child: const Icon(
                  Icons.expand_more,
                  size: 20,
                  color: RiftColors.gold,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: RiftMotion.quick,
            curve: RiftMotion.ease,
            alignment: Alignment.topLeft,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: RuleRichText(widget.item.answer),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Cartes d'exemple : visuel officiel, nom, zoom au toucher.
class _Examples extends StatelessWidget {
  const _Examples({required this.cards});

  final List<GuideCard> cards;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final card = cards[index];
              return PressScale(
                onTap: () => showGuideCardZoom(context, card),
                child: SizedBox(
                  width: 118,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(RiftRadius.card),
                          child: card.image.isEmpty
                              ? ColoredBox(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: Center(
                                    child: Text(card.name, style: text.small),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: cardThumb(
                                    card.image,
                                    width: CardArtSize.tile,
                                  ),
                                  cacheManager: riftImageCache,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) =>
                                      const SizedBox.shrink(),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        card.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.mono.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text('© Riot Games', style: text.mono.copyWith(fontSize: 10)),
      ],
    );
  }
}

/// Sections officielles de la mécanique, repliées par défaut : la fiche
/// répond d'abord, le texte intégral n'est là que pour trancher.
class _OfficialSections extends ConsumerStatefulWidget {
  const _OfficialSections({required this.sections});

  final List<String> sections;

  @override
  ConsumerState<_OfficialSections> createState() => _OfficialSectionsState();
}

class _OfficialSectionsState extends ConsumerState<_OfficialSections> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final document = ref.watch(rulesProvider).valueOrNull;
    final located = <RuleLocation>[
      for (final id in widget.sections)
        ?document?.locate(id, fromBookKey: 'core'),
    ];

    if (!_open) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'En cas de doute, ce texte fait foi : '
            '${located.isEmpty ? widget.sections.length : located.length} '
            'section${located.length > 1 ? 's' : ''} du document officiel.',
            style: text.small,
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: 'Voir le texte officiel',
            icon: Icons.expand_more,
            onPressed: () => setState(() => _open = true),
          ),
        ],
      );
    }

    if (located.isEmpty) {
      return Text(
        'Le texte officiel n’a pas pu être chargé. '
        'Il reste consultable depuis les règles officielles.',
        style: text.small,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final location in located) ...[
          RiftPanel(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MonoBadge(label: location.section.bareNumber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location.section.title,
                        style: text.displaySmall.copyWith(fontSize: 17),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ouvrir dans le lecteur',
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => openRuleLocation(context, location),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                for (final entry in location.section.entries)
                  RuleEntryView(entry: entry),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        GhostButton(
          label: 'Replier le texte officiel',
          icon: Icons.expand_less,
          onPressed: () => setState(() => _open = false),
        ),
      ],
    );
  }
}
