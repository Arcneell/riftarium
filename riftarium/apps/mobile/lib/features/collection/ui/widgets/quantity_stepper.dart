import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/design/reveal.dart';
import '../../../../app/theme.dart';

/// Trois tailles : une ligne de liste, un lot, la fiche carte (où la quantité
/// possédée est le chiffre principal du bloc).
enum StepperSize { compact, normal, large }

/// Compteur « − n + » : deux pastilles rondes (contour pour retirer, or pour
/// ajouter) encadrent la quantité. Chaque pas donne un retour haptique.
/// Sans dépendance à Material : la fiche carte, la collection et la wishlist
/// l'utilisent aussi bien sous Cupertino que sous Material.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.enabled = true,
    this.semanticsLabel,
    this.canDecrease = true,
    this.size = StepperSize.normal,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool enabled;
  final String? semanticsLabel;

  /// Faux quand le lot à décrémenter n'est pas identifiable (plusieurs lots).
  final bool canDecrease;

  final StepperSize size;

  double get _diameter => switch (size) {
    StepperSize.compact => 30,
    StepperSize.normal => 36,
    StepperSize.large => 44,
  };

  void _step(int next) {
    HapticFeedback.selectionClick();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    // La fiche carte affiche la quantité en grand, comme un chiffre de blason.
    final valueStyle = size == StepperSize.large
        ? text.displayMedium.copyWith(fontSize: 30, color: RiftColors.gold)
        : text.monoStrong.copyWith(
            fontSize: size == StepperSize.compact ? 14 : 16,
          );
    return Semantics(
      label: semanticsLabel,
      value: '$value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            tooltip: 'Un exemplaire de moins',
            diameter: _diameter,
            onPressed: enabled && canDecrease && value > min
                ? () => _step(value - 1)
                : null,
          ),
          Container(
            constraints: BoxConstraints(
              minWidth: size == StepperSize.large ? 60 : 34,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            child: Text('$value', style: valueStyle),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: 'Un exemplaire de plus',
            diameter: _diameter,
            filled: true,
            onPressed: enabled && value < max ? () => _step(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Pastille ronde : or plein pour ajouter, contour parchemin pour retirer.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.diameter,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final double diameter;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = riftText(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: tooltip,
      child: PressScale(
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: RiftMotion.quick,
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: filled ? RiftColors.goldGradient : null,
              color: filled ? null : theme.colorScheme.surfaceContainerHighest,
              border: filled
                  ? null
                  : Border.all(color: theme.colorScheme.outline),
              boxShadow: filled && enabled ? RiftShadows.soft : null,
            ),
            child: Icon(
              icon,
              size: diameter * 0.5,
              color: filled ? Colors.white : text.ink,
            ),
          ),
        ),
      ),
    );
  }
}
