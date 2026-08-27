import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../cards/domain/card.dart';
import '../application/decks_controller.dart';
import '../domain/deck.dart';
import '../domain/deck_rules.dart';
import 'deck_form_dialogs.dart';

/// Types et domaines proposés par les filtres, avec leurs libellés français.
const Map<String, String> _typeLabels = {
  'Unit': 'Unité',
  'Spell': 'Sort',
  'Gear': 'Équipement',
  'Rune': 'Rune',
  'Legend': 'Légende',
  'Battlefield': 'Champ de bataille',
};

const Map<String, String> _domainLabels = {
  'Fury': 'Fureur',
  'Calm': 'Calme',
  'Mind': 'Esprit',
  'Body': 'Corps',
  'Chaos': 'Chaos',
  'Order': 'Ordre',
};

/// Éditeur de deck : recherche de cartes, ajout/retrait, compteurs, sauvegarde.
class DeckEditorScreen extends ConsumerStatefulWidget {
  const DeckEditorScreen({super.key, required this.deck});

  final Deck deck;

  @override
  ConsumerState<DeckEditorScreen> createState() => _DeckEditorScreenState();
}

class _DeckEditorScreenState extends ConsumerState<DeckEditorScreen> {
  late List<DeckCard> _cards = List<DeckCard>.from(widget.deck.cards);
  late DeckDraft _draft = DeckDraft(
    name: widget.deck.name,
    description: widget.deck.description ?? '',
    format: widget.deck.format,
    isPublic: widget.deck.isPublic,
  );

  final _search = TextEditingController();
  Timer? _debounce;
  DeckCardQuery _query = const DeckCardQuery();
  bool _showDeck = false;
  bool _saving = false;

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
      setState(() => _query = _query.copyWith(text: value.trim(), page: 1));
    });
  }

  void _add(RiftCard card) {
    final result = addCardToDeck(_cards, card, format: _draft.format);
    setState(() => _cards = result.cards);
    final message = result.refusal ?? result.notice;
    if (message != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  void _remove(String cardId) {
    setState(() => _cards = removeCardFromDeck(_cards, cardId));
  }

  Future<void> _editSettings() async {
    final draft = await showDeckDraftDialog(
      context,
      title: 'Réglages du deck',
      initial: _draft,
      confirmLabel: 'Valider',
    );
    if (draft == null) return;
    setState(() => _draft = draft);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(deckActionsProvider)
          .update(
            widget.deck.id,
            DeckInput(
              name: _draft.name,
              description: _draft.description,
              format: _draft.format,
              isPublic: _draft.isPublic,
              cards: _cards
                  .map((entry) => DeckCardInput(entry.card.id, entry.qty))
                  .toList(),
            ),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      await showAdaptiveMessage(
        context,
        title: 'Enregistrement impossible',
        message: error.message,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupDeck(_cards);
    return AdaptiveScaffold(
      title: _draft.name.isEmpty ? 'Éditeur' : _draft.name,
      trailing: IconButton(
        tooltip: 'Enregistrer',
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
      ),
      body: Column(
        children: [
          _Counters(groups: groups),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: ChoicePill(
                    label: 'Cartes',
                    selected: !_showDeck,
                    onTap: () => setState(() => _showDeck = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoicePill(
                    label: 'Mon deck (${_cards.length})',
                    selected: _showDeck,
                    onTap: () => setState(() => _showDeck = true),
                  ),
                ),
                IconButton(
                  tooltip: 'Réglages du deck',
                  onPressed: _editSettings,
                  icon: const Icon(Icons.tune_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: _showDeck
                ? _DeckList(groups: groups, onAdd: _add, onRemove: _remove)
                : _CardSearch(
                    controller: _search,
                    query: _query,
                    onTextChanged: _onSearchChanged,
                    onQueryChanged: (query) => setState(() => _query = query),
                    onAdd: _add,
                    quantityOf: (card) => inDeckQty(_cards, card),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Compteurs en direct : légende, champs de bataille, runes, deck principal.
class _Counters extends StatelessWidget {
  const _Counters({required this.groups});

  final Map<String, List<DeckCard>> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          for (final zone in deckZones)
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${zoneCount(groups, zone.key)}/${zone.target}'
                    '${zone.key == 'main' ? '+' : ''}',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    zone.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Recherche de cartes : texte, type, domaine, puis grille de résultats.
class _CardSearch extends ConsumerWidget {
  const _CardSearch({
    required this.controller,
    required this.query,
    required this.onTextChanged,
    required this.onQueryChanged,
    required this.onAdd,
    required this.quantityOf,
  });

  final TextEditingController controller;
  final DeckCardQuery query;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<DeckCardQuery> onQueryChanged;
  final ValueChanged<RiftCard> onAdd;
  final int Function(RiftCard) quantityOf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(deckCardSearchProvider(query));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: TextField(
            controller: controller,
            onChanged: onTextChanged,
            decoration: const InputDecoration(
              hintText: 'Nom, texte, identifiant…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _FilterMenu(
                label: 'Type',
                value: query.type,
                labels: _typeLabels,
                onSelected: (value) => onQueryChanged(
                  value == null
                      ? query.copyWith(clearType: true, page: 1)
                      : query.copyWith(type: value, page: 1),
                ),
              ),
              const SizedBox(width: 8),
              _FilterMenu(
                label: 'Domaine',
                value: query.domain,
                labels: _domainLabels,
                onSelected: (value) => onQueryChanged(
                  value == null
                      ? query.copyWith(clearDomain: true, page: 1)
                      : query.copyWith(domain: value, page: 1),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorView(
              message: error is ApiException
                  ? error.message
                  : 'Recherche impossible.',
              onRetry: () => ref.invalidate(deckCardSearchProvider(query)),
            ),
            data: (page) => page.items.isEmpty
                ? const EmptyView(
                    title: 'Aucune carte',
                    detail: 'Essaie un autre nom ou retire un filtre.',
                    icon: Icons.search_off_outlined,
                  )
                : Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 120,
                                childAspectRatio: 0.6,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                              ),
                          itemCount: page.items.length,
                          itemBuilder: (context, index) {
                            final card = page.items[index];
                            return _SearchTile(
                              card: card,
                              inDeck: quantityOf(card),
                              onTap: () => onAdd(card),
                            );
                          },
                        ),
                      ),
                      _Pager(
                        page: page.page,
                        hasMore: page.hasMore,
                        onChanged: (value) =>
                            onQueryChanged(query.copyWith(page: value)),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _SearchTile extends StatelessWidget {
  const _SearchTile({
    required this.card,
    required this.inDeck,
    required this.onTap,
  });

  final RiftCard card;
  final int inDeck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CardImage(card: card),
              if (inDeck > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '×$inDeck',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Une seule ligne : la tuile a une hauteur fixe (childAspectRatio).
          Text(
            card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Contenu du deck, zone par zone, avec les boutons + et −.
class _DeckList extends StatelessWidget {
  const _DeckList({
    required this.groups,
    required this.onAdd,
    required this.onRemove,
  });

  final Map<String, List<DeckCard>> groups;
  final ValueChanged<RiftCard> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = groups.values.every((zone) => zone.isEmpty);
    if (empty) {
      return const EmptyView(
        title: 'Deck vide',
        detail: 'Choisis d’abord ta légende, puis ajoute des cartes.',
        icon: Icons.style_outlined,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final zone in deckZones)
          if (groups[zone.key]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                '${zone.label} · ${zoneCount(groups, zone.key)}/${zone.target}'
                '${zone.key == 'main' ? '+' : ''}',
                style: theme.textTheme.titleSmall,
              ),
            ),
            for (final entry in groups[zone.key]!)
              ListTile(
                leading: CardImage(card: entry.card, width: 36),
                title: Text(entry.card.name),
                subtitle: Text(entry.card.displayCode),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Retirer un exemplaire',
                      onPressed: () => onRemove(entry.card.id),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${entry.qty}'),
                    IconButton(
                      tooltip: 'Ajouter un exemplaire',
                      onPressed: () => onAdd(entry.card),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
          ],
      ],
    );
  }
}

/// Sélecteur d'un filtre à choix unique (avec « Tous »).
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.labels,
    required this.onSelected,
  });

  final String label;
  final String? value;
  final Map<String, String> labels;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = value == null ? label : (labels[value] ?? value!);
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: (selected) => onSelected(selected == '' ? null : selected),
      itemBuilder: (context) => [
        PopupMenuItem(value: '', child: Text('Tous ($label)')),
        for (final entry in labels.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: ChoicePill(label: current, selected: value != null),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.hasMore,
    required this.onChanged,
  });

  final int page;
  final bool hasMore;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (page <= 1 && !hasMore) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: page <= 1 ? null : () => onChanged(page - 1),
            child: const Text('← Précédent'),
          ),
          Text('page $page'),
          TextButton(
            onPressed: hasMore ? () => onChanged(page + 1) : null,
            child: const Text('Suivant →'),
          ),
        ],
      ),
    );
  }
}
