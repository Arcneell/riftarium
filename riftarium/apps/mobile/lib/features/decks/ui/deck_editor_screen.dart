import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/components.dart';
import '../../../app/design/motion_utils.dart';
import '../../../app/design/reveal.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../cards/domain/card.dart';
import '../application/decks_controller.dart';
import '../domain/deck.dart';
import '../domain/deck_rules.dart';
import 'deck_form_dialogs.dart';
import 'deck_widgets.dart';

/// Types proposés par le filtre de recherche, avec leurs libellés français.
const Map<String, String> _typeLabels = {
  'Unit': 'Unité',
  'Spell': 'Sort',
  'Gear': 'Équipement',
  'Rune': 'Rune',
  'Legend': 'Légende',
  'Battlefield': 'Champ de bataille',
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
      // Le dernier message chasse le précédent : c'est celui-ci qui compte.
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  void _remove(String cardId) {
    setState(() => _cards = removeCardFromDeck(_cards, cardId));
  }

  /// Exemplaires par carte : ce qui compte pour savoir si l'édition diffère du
  /// deck enregistré (l'ordre des lignes n'a pas de sens pour l'API).
  static Map<String, int> _quantities(List<DeckCard> cards) => {
    for (final entry in cards) entry.card.id: entry.qty,
  };

  /// L'édition en cours diffère du deck enregistré : quitter perdrait le
  /// travail. Un deck fraîchement créé arrive vide et sans carte : il n'est
  /// « modifié » qu'une fois une carte ajoutée ou un réglage changé.
  bool get _dirty {
    final deck = widget.deck;
    return _draft.name != deck.name ||
        _draft.description != (deck.description ?? '') ||
        _draft.format != deck.format ||
        _draft.isPublic != deck.isPublic ||
        !mapEquals(_quantities(_cards), _quantities(deck.cards));
  }

  /// Sortie de l'éditeur avec des changements non enregistrés.
  Future<void> _confirmLeave(bool didPop) async {
    if (didPop || !mounted) return;
    final leave = await showAdaptiveMessage(
      context,
      title: 'Quitter sans enregistrer ?',
      message:
          'Les cartes ajoutées et les réglages modifiés seront perdus. '
          'Enregistre d’abord pour les garder.',
      closeLabel: 'Rester',
      confirmLabel: 'Quitter',
      destructive: true,
    );
    if (!leave || !mounted) return;
    Navigator.of(context).pop();
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
    } on Object catch (error) {
      if (!mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Enregistrement impossible',
        message: error is ApiException
            ? error.message
            : 'Le deck n’a pas pu être envoyé. Réessaie dans un instant.',
      );
    } finally {
      // Le bouton doit toujours redevenir actif, même après une erreur
      // inattendue : sinon l'éditeur reste bloqué en « enregistrement ».
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupDeck(_cards);
    // Le libellé compte les exemplaires, comme les compteurs de zone.
    final copies = _cards.fold<int>(0, (total, entry) => total + entry.qty);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) => _confirmLeave(didPop),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _EditorBar(name: _draft.name, onSettings: _editSettings),
              _Counters(groups: groups),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoicePill(
                        label: 'Cartes',
                        expand: true,
                        icon: Icons.search,
                        selected: !_showDeck,
                        onTap: () => setState(() => _showDeck = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoicePill(
                        label: 'Mon deck ($copies)',
                        expand: true,
                        icon: Icons.layers_outlined,
                        selected: _showDeck,
                        onTap: () => setState(() => _showDeck = true),
                      ),
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
                        onQueryChanged: (query) =>
                            setState(() => _query = query),
                        onAdd: _add,
                        quantityOf: (card) => inDeckQty(_cards, card),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _SaveBar(saving: _saving, onSave: _save),
      ),
    );
  }
}

/// Barre du haut : retour, nom du deck, réglages.
class _EditorBar extends StatelessWidget {
  const _EditorBar({required this.name, required this.onSettings});

  final String name;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ÉDITEUR', style: text.eyebrow),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? 'Deck sans nom' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.displaySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Réglages du deck',
            onPressed: onSettings,
            icon: const Icon(Icons.tune_outlined),
          ),
        ],
      ),
    );
  }
}

/// Compteurs en direct : vert quand la zone est complète, rouge au dépassement.
class _Counters extends StatelessWidget {
  const _Counters({required this.groups});

  final Map<String, List<DeckCard>> groups;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Row(
        children: [
          for (final zone in deckZones)
            Expanded(
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      final count = zoneCount(groups, zone.key);
                      final open = zone.key == 'main';
                      final label = '$count/${zone.target}${open ? '+' : ''}';
                      final color = switch (count) {
                        _ when !open && count > zone.target => RiftColors.fury,
                        _ when count >= zone.target => RiftColors.body,
                        _ => RiftColors.gold,
                      };
                      return AnimatedSwitcher(
                        duration: riftDuration(context, RiftMotion.quick),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: MonoBadge(
                          key: ValueKey(label),
                          label: label,
                          color: color,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    zone.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.small.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Recherche de cartes : texte, type, domaine, puis grille compacte.
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
    // Les visuels de la page reçue sont mis en cache dès son arrivée : le
    // retour sur une page déjà vue ne repasse pas par le réseau.
    ref.listen(deckCardSearchProvider(query), (previous, next) {
      final items = next.valueOrNull?.items;
      if (items != null) precacheCardThumbs(context, items);
    });
    final results = ref.watch(deckCardSearchProvider(query));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: TextField(
            controller: controller,
            onChanged: onTextChanged,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'Nom, texte, identifiant…',
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
                labels: {
                  for (final domain in filterDomains)
                    domain: domainLabel(domain),
                },
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
                // Le panneau défile : sur un écran court il ne déborde pas
                // de la place laissée par la recherche et ses filtres.
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: InvitePanel(
                      icon: Icons.search_off_outlined,
                      title: 'Aucune carte',
                      message: 'Essaie un autre nom, ou retire un filtre.',
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                          // Grille compacte : on voit beaucoup de cartes d'un
                          // coup, un tap en ajoute une.
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 132,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.62,
                              ),
                          itemCount: page.items.length,
                          itemBuilder: (context, index) {
                            final card = page.items[index];
                            return _SearchTile(
                              card: card,
                              index: index,
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

/// Une carte de la galerie : un tap l'ajoute, le compteur se met à jour.
class _SearchTile extends StatelessWidget {
  const _SearchTile({
    required this.card,
    required this.index,
    required this.inDeck,
    required this.onTap,
  });

  final RiftCard card;
  final int index;
  final int inDeck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Reveal(
      index: index,
      child: PressScale(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Stack(
                children: [
                  CardImage(card: card),
                  Positioned(
                    right: 5,
                    bottom: 5,
                    child: AnimatedSwitcher(
                      duration: riftDuration(context, RiftMotion.quick),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: inDeck == 0
                          ? const SizedBox.shrink()
                          : MonoBadge(
                              key: ValueKey(inDeck),
                              label: '×$inDeck',
                              filled: true,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            // Une seule ligne : la tuile a une hauteur fixe.
            Text(
              card.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.small.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenu du deck, zone par zone, avec les boutons − et +.
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
    if (groups.values.every((zone) => zone.isEmpty)) {
      return Padding(
        padding: const EdgeInsets.all(18),
        child: InvitePanel(
          icon: Icons.style_outlined,
          title: 'Deck vide',
          message: 'Commence par la légende : elle fixe les domaines du deck.',
        ),
      );
    }
    // Un sliver par zone : les lignes ne sont construites qu'à l'approche de
    // l'écran, un deck de 60 cartes reste fluide.
    return CustomScrollView(
      slivers: [
        for (final zone in deckZones)
          if (groups[zone.key]!.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: SectionTitle(
                title:
                    '${zone.label} · ${zoneCount(groups, zone.key)}'
                    '/${zone.target}${zone.key == 'main' ? '+' : ''}',
              ),
            ),
            SliverList.builder(
              itemCount: groups[zone.key]!.length,
              itemBuilder: (context, index) {
                final entry = groups[zone.key]![index];
                return _DeckRow(
                  entry: entry,
                  onAdd: () => onAdd(entry.card),
                  onRemove: () => onRemove(entry.card.id),
                );
              },
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

/// Une ligne du deck : vignette, nom, code et son stepper.
class _DeckRow extends StatelessWidget {
  const _DeckRow({
    required this.entry,
    required this.onAdd,
    required this.onRemove,
  });

  final DeckCard entry;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 12, 4),
      child: Row(
        children: [
          CardImage(card: entry.card, width: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.body,
                ),
                Text(entry.card.displayCode, style: text.mono),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer un exemplaire',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          AnimatedSwitcher(
            duration: riftDuration(context, RiftMotion.quick),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: Text(
              '${entry.qty}',
              key: ValueKey(entry.qty),
              style: text.monoStrong,
            ),
          ),
          IconButton(
            tooltip: 'Ajouter un exemplaire',
            onPressed: onAdd,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
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
      onSelected: (selected) => onSelected(selected == '' ? null : selected),
      itemBuilder: (context) => [
        PopupMenuItem(value: '', child: Text('Tous ($label)')),
        for (final entry in labels.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: ChoicePill(label: current, selected: value != null, menu: true),
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
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: page <= 1 ? null : () => onChanged(page - 1),
            child: const Text('Précédent'),
          ),
          Flexible(
            child: Text(
              'page $page',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.mono,
            ),
          ),
          TextButton(
            onPressed: hasMore ? () => onChanged(page + 1) : null,
            child: const Text('Suivant'),
          ),
        ],
      ),
    );
  }
}

/// Barre d'enregistrement épinglée en bas de l'éditeur.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.saving, required this.onSave});

  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
          child: GoldButton(
            label: 'Enregistrer',
            icon: Icons.check,
            loading: saving,
            onPressed: onSave,
          ),
        ),
      ),
    );
  }
}
