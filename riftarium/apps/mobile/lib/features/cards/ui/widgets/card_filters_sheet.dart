import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/components.dart';
import '../../../../app/theme.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cards_controller.dart';
import '../../domain/card_labels.dart';
import 'pills.dart';

/// Ouvre la feuille de filtres : parchemin, poignée de glissement, hauteur
/// libre (le thème de l'application habille déjà les feuilles modales).
Future<void> showCardFiltersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const CardFiltersSheet(),
  );
}

/// Contenu de la feuille : chaque choix s'applique immédiatement à la grille,
/// le bouton or ne fait que refermer sur le nombre de cartes trouvées.
class CardFiltersSheet extends ConsumerWidget {
  const CardFiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final filters = ref.watch(cardFiltersProvider);
    final controller = ref.read(cardFiltersProvider.notifier);
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    final sets = ref.watch(cardSetsProvider).valueOrNull ?? const [];
    final total = ref.watch(cardsListProvider).valueOrNull?.total;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('Filtres', style: text.displayMedium)],
                  ),
                ),
                const GoldRule(width: 40),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              children: [
                if (sets.isNotEmpty)
                  _Facet(
                    title: 'Set',
                    child: _Options(
                      selected: filters.setId,
                      options: [for (final set in sets) (set.setId, set.label)],
                      onSelected: controller.setSetId,
                    ),
                  ),
                _Facet(
                  title: 'Type',
                  child: _Options(
                    selected: filters.type,
                    options: [
                      for (final entry in kTypeLabels.entries)
                        (entry.key, entry.value),
                    ],
                    onSelected: controller.setType,
                  ),
                ),
                _Facet(
                  title: 'Domaine',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterPill(
                        label: 'Tous',
                        selected: filters.domain == null,
                        onPressed: () => controller.setDomain(null),
                      ),
                      for (final domain in kFilterableDomains)
                        _DomainOption(
                          domain: domain,
                          selected: filters.domain == domain,
                          onPressed: () => controller.setDomain(
                            filters.domain == domain ? null : domain,
                          ),
                        ),
                    ],
                  ),
                ),
                _Facet(
                  title: 'Rareté',
                  child: _Options(
                    selected: filters.rarity,
                    options: [
                      for (final entry in kRarityLabels.entries)
                        (entry.key, entry.value),
                    ],
                    onSelected: controller.setRarity,
                  ),
                ),
                _Facet(
                  title: 'Coût en énergie',
                  child: _Options(
                    selected: filters.energy,
                    options: [
                      for (final cost in kEnergyCosts)
                        (cost, energyLabel(cost)),
                    ],
                    onSelected: controller.setEnergy,
                  ),
                ),
                _Facet(
                  title: 'Tri',
                  child: _Options(
                    selected: filters.sort,
                    allLabel: kSortLabels[null]!,
                    options: const [
                      ('rarity', 'Rareté'),
                      ('random', 'Aléatoire'),
                    ],
                    onSelected: controller.setSort,
                  ),
                ),
                if (signedIn)
                  _Facet(
                    title: 'Ma collection',
                    child: _Options(
                      selected: filters.owned,
                      allLabel: kOwnedLabels[null]!,
                      options: const [('1', 'Possédées'), ('0', 'Manquantes')],
                      onSelected: controller.setOwned,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
            child: Row(
              children: [
                // Largeur naturelle : dans une colonne étroite, le libellé
                // se coupait sur trois lignes.
                TextButton(
                  onPressed: filters.isEmpty ? null : controller.clearFacets,
                  child: const Text('Réinitialiser'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GoldButton(
                    label: total == null
                        ? 'Voir les cartes'
                        : 'Voir ${cardCountLabel(total).toLowerCase()}',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une facette : son titre de section et ses pastilles.
class _Facet extends StatelessWidget {
  const _Facet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title: title,
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 10),
        ),
        child,
      ],
    );
  }
}

/// Le choix « Tous » plus une pastille par valeur.
class _Options extends StatelessWidget {
  const _Options({
    required this.selected,
    required this.options,
    required this.onSelected,
    this.allLabel = 'Tous',
  });

  final String? selected;

  /// Couples (valeur envoyée à l'API, libellé affiché).
  final List<(String, String)> options;
  final ValueChanged<String?> onSelected;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterPill(
          label: allLabel,
          selected: selected == null,
          onPressed: () => onSelected(null),
        ),
        for (final (value, label) in options)
          FilterPill(
            label: label,
            selected: selected == value,
            onPressed: () => onSelected(selected == value ? null : value),
          ),
      ],
    );
  }
}

/// Domaine : la pastille de couleur du jeu, cerclée d'or quand elle est prise.
class _DomainOption extends StatelessWidget {
  const _DomainOption({
    required this.domain,
    required this.selected,
    required this.onPressed,
  });

  final String domain;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: RiftMotion.quick,
          curve: RiftMotion.ease,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RiftRadius.full),
            border: Border.all(
              color: selected ? RiftColors.gold : Colors.transparent,
              width: 1.6,
            ),
            boxShadow: selected ? RiftShadows.glowGold : null,
          ),
          child: Opacity(
            opacity: selected ? 1 : 0.78,
            child: DomainChip(domain: domain),
          ),
        ),
      ),
    );
  }
}
