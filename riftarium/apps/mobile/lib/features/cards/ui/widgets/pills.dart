import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

/// Petites pastilles de la cartothèque : choix dans la feuille de filtres,
/// rappel d'un filtre actif. Elles suivent le `chipTheme` de l'application
/// (contour or pâle, pilule, pas de coche) et marquent la sélection à l'or.

/// Option d'une facette. Sélectionnée : fond et contour or, texte appuyé.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.avatar,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  /// Pastille de tête (rune d'un domaine, chiffre d'énergie).
  final Widget? avatar;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return FilterChip(
      avatar: avatar,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPressed(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: text.small.copyWith(
        fontSize: 13.5,
        color: selected ? RiftColors.goldDeep : text.ink,
        fontVariations: RiftFonts.weight(selected ? 600 : 400),
      ),
      side: BorderSide(
        color: selected
            ? RiftColors.gold
            : Theme.of(context).colorScheme.outline,
        width: selected ? 1.4 : 1,
      ),
    );
  }
}

/// Filtre actif, avec sa croix : toucher la puce retire le critère.
class RemovablePill extends StatelessWidget {
  const RemovablePill({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Semantics(
      button: true,
      label: 'Retirer le filtre $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onRemove,
        child: Container(
          padding: const EdgeInsets.only(left: 12, right: 7, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: RiftColors.gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(RiftRadius.full),
            border: Border.all(color: RiftColors.gold.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: text.small.copyWith(
                  fontSize: 13,
                  color: text.ink,
                  fontVariations: RiftFonts.weight(600),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 15, color: RiftColors.goldDeep),
            ],
          ),
        ),
      ),
    );
  }
}
