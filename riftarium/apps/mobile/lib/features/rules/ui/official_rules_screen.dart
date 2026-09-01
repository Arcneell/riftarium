import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/profile_action.dart';
import '../application/rules_providers.dart';
import '../domain/rules.dart';
import 'rule_chapter_screen.dart';
import 'rule_section_screen.dart';
import 'rules_navigation.dart';
import 'widgets/rules_search_field.dart';

/// Le texte officiel, en intégralité : les deux documents, cherchables et
/// consultables hors ligne. Dernier palier des règles — celui qui fait foi.
class OfficialRulesScreen extends ConsumerStatefulWidget {
  const OfficialRulesScreen({super.key});

  @override
  ConsumerState<OfficialRulesScreen> createState() =>
      _OfficialRulesScreenState();
}

class _OfficialRulesScreenState extends ConsumerState<OfficialRulesScreen> {
  static const Duration _debounceDelay = Duration(milliseconds: 250);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _bookKey = 'core';
  bool _refreshing = false;

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

  /// La recherche parcourt les 2 949 règles : on attend la fin de la frappe.
  void _onQueryChanged() {
    final value = _searchController.text.trim();
    if (value == _query) return;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      setState(() => _query = _searchController.text.trim());
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final outcome = await ref.read(rulesProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
    await showAdaptiveMessage(
      context,
      title: 'Règles officielles',
      message: outcome.message,
    );
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on Object {
        opened = false;
      }
    }
    if (opened || !mounted) return;
    await showAdaptiveMessage(
      context,
      title: 'PDF officiel',
      message: 'Impossible d’ouvrir le document dans le navigateur.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          PageBanner(
            title: 'Règles officielles',
            eyebrow: 'Dernier recours',
            art: RiftBanners.rules,
            expandedHeight: 200,
            leading: RulesBackButton(),
            actions: [ProfileAction()],
          ),
          ...rules.when(
            loading: () => const [
              SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
            ],
            error: (error, stack) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorView(
                  message: 'Impossible de charger les règles officielles.',
                  onRetry: () => ref.invalidate(rulesProvider),
                ),
              ),
            ],
            data: _bodySlivers,
          ),
        ],
      ),
    );
  }

  List<Widget> _bodySlivers(RulesDocument document) {
    if (document.books.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            title: 'Règles indisponibles',
            detail: 'Le document officiel n’a pas pu être lu.',
          ),
        ),
      ];
    }
    final book = document.bookByKey(_bookKey) ?? document.books.first;
    final searching = _query.length >= kRuleSearchMinLength;
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (document.books.length > 1)
                SizedBox(
                  width: double.infinity,
                  child: _BookSelector(
                    books: document.books,
                    selectedKey: book.key,
                    onChanged: (key) => setState(() => _bookKey = key),
                  ),
                ),
              const SizedBox(height: 14),
              RulesSearchField(
                controller: _searchController,
                label: 'Rechercher dans les règles',
                hint: 'Mot-clé ou numéro de règle…',
              ),
              const SizedBox(height: 12),
              _BookMeta(
                book: book,
                refreshing: _refreshing,
                onRefresh: _refresh,
                onOpenSource: _openSource,
              ),
            ],
          ),
        ),
      ),
      if (searching)
        ..._searchSlivers(book)
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
          sliver: SliverList.separated(
            itemCount: book.chapters.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final chapter = book.chapters[index];
              return Reveal(
                index: index,
                child: _ChapterTile(book: book, chapter: chapter),
              );
            },
          ),
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  List<Widget> _searchSlivers(RuleBook book) {
    final hits = ref.watch(ruleSearchProvider(_query));
    if (hits.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 24, 18, 0),
            child: EmptyView(
              title: 'Aucune règle trouvée',
              detail: 'Essaie un autre mot-clé, ou un numéro comme 002.',
              icon: Icons.search_off_outlined,
            ),
          ),
        ),
      ];
    }
    return [
      SliverToBoxAdapter(
        child: SectionTitle(
          eyebrow: 'Résultats',
          title:
              '${hits.length} règle${hits.length > 1 ? 's' : ''} '
              'pour « $_query »',
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        sliver: SliverList.separated(
          itemCount: hits.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => Reveal(
            index: index,
            child: _SearchHitTile(hit: hits[index]),
          ),
        ),
      ),
    ];
  }
}

/// Bascule entre les deux documents.
class _BookSelector extends StatelessWidget {
  const _BookSelector({
    required this.books,
    required this.selectedKey,
    required this.onChanged,
  });

  final List<RuleBook> books;
  final String selectedKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSlidingSegmentedControl<String>(
        groupValue: selectedKey,
        onValueChanged: (value) {
          if (value != null) onChanged(value);
        },
        children: {
          for (final book in books)
            book.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(book.title, textAlign: TextAlign.center),
            ),
        },
      );
    }
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        for (final book in books)
          ButtonSegment<String>(value: book.key, label: Text(book.title)),
      ],
      selected: {selectedKey},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Sous-titre du document, date, PDF et rafraîchissement.
class _BookMeta extends StatelessWidget {
  const _BookMeta({
    required this.book,
    required this.refreshing,
    required this.onRefresh,
    required this.onOpenSource,
  });

  final RuleBook book;
  final bool refreshing;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String url) onOpenSource;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(book.subtitle, style: text.small),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MonoBadge(label: 'Mis à jour le ${book.updated}'),
            MonoBadge(
              label:
                  '${formatRuleCount(book.ruleCount)} '
                  'règle${book.ruleCount > 1 ? 's' : ''}',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            AdaptiveTextButton(
              label: 'PDF officiel',
              onPressed: book.source.isEmpty
                  ? null
                  : () => onOpenSource(book.source),
            ),
            if (refreshing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              )
            else
              AdaptiveTextButton(label: 'Actualiser', onPressed: onRefresh),
          ],
        ),
      ],
    );
  }
}

/// Un chapitre du document.
class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.book, required this.chapter});

  final RuleBook book;
  final RuleChapter chapter;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      onTap: () => pushAdaptiveScreen(
        context,
        (_) => RuleChapterScreen(book: book, chapter: chapter),
      ),
      child: Row(
        children: [
          MonoBadge(label: chapter.bareNumber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chapter.title, style: text.displaySmall),
                const SizedBox(height: 2),
                Text(
                  '${chapter.sections.length} '
                  'section${chapter.sections.length > 1 ? 's' : ''} · '
                  '${formatRuleCount(chapter.ruleCount)} '
                  'règle${chapter.ruleCount > 1 ? 's' : ''}',
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

/// Un résultat de recherche : numéro, fil d'Ariane, extrait.
class _SearchHitTile extends StatelessWidget {
  const _SearchHitTile({required this.hit});

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
                  hit.breadcrumb,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.small.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(hit.snippet, style: text.body.copyWith(fontSize: 14.5)),
        ],
      ),
    );
  }
}
