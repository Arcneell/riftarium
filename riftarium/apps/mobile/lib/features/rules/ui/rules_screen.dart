import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/adaptive.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../application/rules_providers.dart';
import '../domain/rules.dart';
import 'rule_chapter_screen.dart';
import 'rule_section_screen.dart';
import 'rules_navigation.dart';

/// Onglet « Règles » : les deux documents officiels, consultables hors ligne.
///
/// Une seule route go_router (`/regles`) : chapitres, sections et renvois
/// s'empilent dans le Navigator de l'onglet.
class RulesScreen extends ConsumerStatefulWidget {
  const RulesScreen({super.key});

  @override
  ConsumerState<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends ConsumerState<RulesScreen> {
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

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
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
    return AdaptiveScaffold(
      title: 'Règles',
      body: rules.when(
        loading: () => const LoadingView(),
        error: (error, stack) => ErrorView(
          message: 'Impossible de charger les règles officielles.',
          onRetry: () => ref.invalidate(rulesProvider),
        ),
        data: (document) => _RulesBody(
          document: document,
          bookKey: _bookKey,
          query: _query,
          searchController: _searchController,
          refreshing: _refreshing,
          onBookChanged: (key) => setState(() => _bookKey = key),
          onClearSearch: _clearSearch,
          onRefresh: _refresh,
          onOpenSource: _openSource,
        ),
      ),
    );
  }
}

class _RulesBody extends ConsumerWidget {
  const _RulesBody({
    required this.document,
    required this.bookKey,
    required this.query,
    required this.searchController,
    required this.refreshing,
    required this.onBookChanged,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onOpenSource,
  });

  final RulesDocument document;
  final String bookKey;
  final String query;
  final TextEditingController searchController;
  final bool refreshing;
  final ValueChanged<String> onBookChanged;
  final VoidCallback onClearSearch;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String url) onOpenSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (document.books.isEmpty) {
      return const EmptyView(
        title: 'Règles indisponibles',
        detail: 'Le document officiel n’a pas pu être lu.',
      );
    }
    final book = document.bookByKey(bookKey) ?? document.books.first;
    final searching = query.length >= kRuleSearchMinLength;
    final hits = searching
        ? ref.watch(ruleSearchProvider(query))
        : const <RuleSearchHit>[];

    return Material(
      type: MaterialType.transparency,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              document: document,
              book: book,
              searchController: searchController,
              refreshing: refreshing,
              onBookChanged: onBookChanged,
              onRefresh: onRefresh,
              onOpenSource: onOpenSource,
            ),
          ),
          if (searching)
            ..._searchSlivers(context, hits)
          else
            SliverList.separated(
              itemCount: book.chapters.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final chapter = book.chapters[index];
                return ListTile(
                  title: Text(chapter.title),
                  subtitle: Text(
                    '${chapter.bareNumber} · ${chapter.sections.length} '
                    'sections · ${chapter.ruleCount} règles',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => pushAdaptiveScreen(
                    context,
                    (_) => RuleChapterScreen(book: book, chapter: chapter),
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _searchSlivers(BuildContext context, List<RuleSearchHit> hits) {
    if (hits.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: EmptyView(
              title: 'Aucune règle trouvée',
              detail:
                  'Essaie un autre mot-clé, ou un numéro de règle comme 002.',
              icon: Icons.search_off_outlined,
            ),
          ),
        ),
      ];
    }
    final theme = Theme.of(context);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${hits.length} règle${hits.length > 1 ? 's' : ''} '
                  'pour « $query »',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              AdaptiveTextButton(label: 'Effacer', onPressed: onClearSearch),
            ],
          ),
        ),
      ),
      SliverList.separated(
        itemCount: hits.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => _SearchHitTile(hit: hits[index]),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.document,
    required this.book,
    required this.searchController,
    required this.refreshing,
    required this.onBookChanged,
    required this.onRefresh,
    required this.onOpenSource,
  });

  final RulesDocument document;
  final RuleBook book;
  final TextEditingController searchController;
  final bool refreshing;
  final ValueChanged<String> onBookChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String url) onOpenSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (document.books.length > 1)
            SizedBox(
              width: double.infinity,
              child: _BookSelector(
                books: document.books,
                selectedKey: book.key,
                onChanged: onBookChanged,
              ),
            ),
          const SizedBox(height: 12),
          Text(book.subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Mis à jour le ${book.updated} · ${book.ruleCount} règles',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Row(
            children: [
              AdaptiveTextButton(
                label: 'PDF officiel ↗',
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
          const SizedBox(height: 4),
          AdaptiveTextField(
            controller: searchController,
            label: 'Rechercher dans les règles',
            placeholder: 'Mot-clé ou numéro de règle…',
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            autocorrect: false,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
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

class _SearchHitTile extends StatelessWidget {
  const _SearchHitTile({required this.hit});

  final RuleSearchHit hit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: () => openRuleLocation(
        context,
        RuleLocation(
          book: hit.book,
          chapter: hit.chapter,
          section: hit.section,
          entry: hit.entry,
        ),
      ),
      title: Text(
        hit.entry.number,
        style: theme.textTheme.titleSmall?.copyWith(
          color: kRiftariumGold,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hit.breadcrumb,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(hit.snippet, style: theme.textTheme.bodySmall),
        ],
      ),
      isThreeLine: true,
    );
  }
}
