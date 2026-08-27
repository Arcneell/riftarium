import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/adaptive.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cards_controller.dart';
import '../../domain/card_labels.dart';
import 'pills.dart';

/// Ouvre la feuille de filtres : feuille modale Material, popup modale
/// Cupertino sur iOS.
Future<void> showCardFiltersSheet(BuildContext context) {
  if (isCupertino(context)) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) =>
          const _CupertinoSheetShell(child: CardFiltersSheet()),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const CardFiltersSheet(),
  );
}

class _CupertinoSheetShell extends StatelessWidget {
  const _CupertinoSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Contenu de la feuille : chaque choix s'applique immédiatement à la liste.
class CardFiltersSheet extends ConsumerWidget {
  const CardFiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(cardFiltersProvider);
    final controller = ref.read(cardFiltersProvider.notifier);
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    final sets = ref.watch(cardSetsProvider).valueOrNull ?? const [];
    final total = ref.watch(cardsListProvider).valueOrNull?.total;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtres',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (!filters.isEmpty)
                  AdaptiveTextButton(
                    label: 'Réinitialiser',
                    onPressed: controller.clearFacets,
                  ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              children: [
                if (sets.isNotEmpty)
                  _FilterSection(
                    label: 'Set',
                    selected: filters.setId,
                    options: [for (final set in sets) (set.setId, set.label)],
                    onSelected: controller.setSetId,
                  ),
                _FilterSection(
                  label: 'Type',
                  selected: filters.type,
                  options: [
                    for (final entry in kTypeLabels.entries)
                      (entry.key, entry.value),
                  ],
                  onSelected: controller.setType,
                ),
                _FilterSection(
                  label: 'Domaine',
                  selected: filters.domain,
                  options: [
                    for (final domain in kFilterableDomains)
                      (domain, domainLabel(domain)),
                  ],
                  onSelected: controller.setDomain,
                ),
                _FilterSection(
                  label: 'Rareté',
                  selected: filters.rarity,
                  options: [
                    for (final entry in kRarityLabels.entries)
                      (entry.key, entry.value),
                  ],
                  onSelected: controller.setRarity,
                ),
                _FilterSection(
                  label: 'Coût en énergie',
                  selected: filters.energy,
                  options: [
                    for (final cost in kEnergyCosts) (cost, energyLabel(cost)),
                  ],
                  onSelected: controller.setEnergy,
                ),
                _FilterSection(
                  label: 'Tri',
                  selected: filters.sort,
                  allLabel: kSortLabels[null]!,
                  options: const [
                    ('rarity', 'Rareté'),
                    ('random', 'Aléatoire'),
                  ],
                  onSelected: controller.setSort,
                ),
                if (signedIn)
                  _FilterSection(
                    label: 'Ma collection',
                    selected: filters.owned,
                    allLabel: kOwnedLabels[null]!,
                    options: const [('1', 'Possédées'), ('0', 'Manquantes')],
                    onSelected: controller.setOwned,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: AdaptiveFilledButton(
                label: total == null
                    ? 'Voir les cartes'
                    : 'Voir ${cardCountLabel(total).toLowerCase()}',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une facette : le choix « Toutes » plus une pastille par valeur.
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.selected,
    required this.options,
    required this.onSelected,
    this.allLabel = 'Tous',
  });

  final String label;
  final String? selected;

  /// Couples (valeur envoyée à l'API, libellé affiché).
  final List<(String, String)> options;
  final ValueChanged<String?> onSelected;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoicePill(
                label: allLabel,
                selected: selected == null,
                onPressed: () => onSelected(null),
              ),
              for (final (value, optionLabel) in options)
                ChoicePill(
                  label: optionLabel,
                  selected: selected == value,
                  onPressed: () => onSelected(selected == value ? null : value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
