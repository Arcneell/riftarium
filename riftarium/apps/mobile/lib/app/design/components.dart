import 'package:flutter/material.dart';

import '../theme.dart';
import 'reveal.dart';

/// Bouton principal : dégradé or, pilule, ombre dorée. Un seul par écran.
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final text = riftText(context);
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 19, color: Colors.white),
        if (icon != null || loading) const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyStrong.copyWith(
              color: Colors.white,
              fontSize: 15.5,
            ),
          ),
        ),
      ],
    );
    return PressScale(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: RiftMotion.quick,
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: RiftColors.goldGradient,
            borderRadius: BorderRadius.circular(RiftRadius.full),
            boxShadow: enabled ? RiftShadows.glowGold : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Bouton secondaire : contour, texte encre.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Sans icône, `OutlinedButton.icon` garderait l'écart icône/libellé et
    // décalerait le texte : on prend le bouton simple.
    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// Panneau parchemin : surface claire, trait or pâle, coins 18.
class RiftPanel extends StatelessWidget {
  const RiftPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.raised = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? RiftColors.darkPaper2 : const Color(0xFFFDFAF2),
        borderRadius: BorderRadius.circular(RiftRadius.md),
        border: Border.all(color: theme.colorScheme.outline),
        boxShadow: raised ? RiftShadows.soft : null,
      ),
      child: child,
    );
    return onTap == null ? panel : PressScale(onTap: onTap, child: panel);
  }
}

/// Titre de section : sur-titre mono doré facultatif + Marcellus.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(18, 28, 18, 12),
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: text.eyebrow),
                  const SizedBox(height: 4),
                ],
                Text(title, style: text.displayMedium.copyWith(fontSize: 23)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Pastille de domaine (Fureur, Calme…) ou étiquette neutre.
class DomainChip extends StatelessWidget {
  const DomainChip({super.key, required this.domain, this.compact = false});

  final String domain;
  final bool compact;

  static const labels = {
    'Fury': 'Fureur',
    'Calm': 'Calme',
    'Mind': 'Esprit',
    'Body': 'Corps',
    'Chaos': 'Chaos',
    'Order': 'Ordre',
    'Colorless': 'Neutre',
  };

  @override
  Widget build(BuildContext context) {
    final color = RiftColors.domain(domain);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final label = labels[domain] ?? domain;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.28 : 0.13),
        borderRadius: BorderRadius.circular(RiftRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 7),
          Text(
            label,
            style: TextStyle(
              fontFamily: RiftFonts.body,
              fontVariations: RiftFonts.weight(600),
              fontSize: compact ? 11 : 12.5,
              color: dark ? color : RiftColors.domainText(domain),
            ),
          ),
        ],
      ),
    );
  }
}

/// Étiquette mono (code de carte, rareté, quantité) : `OGN 209`, `×3`.
class MonoBadge extends StatelessWidget {
  const MonoBadge({
    super.key,
    required this.label,
    this.filled = false,
    this.color,
  });

  final String label;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final tint = color ?? RiftColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled
            ? RiftColors.inkStrong.withValues(alpha: 0.78)
            : tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(RiftRadius.sm),
        border: filled ? null : Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: text.mono.copyWith(
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : text.ink,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

/// Barre de progression prismatique (complétion d'un set).
class PrismBar extends StatelessWidget {
  const PrismBar({super.key, required this.value, this.height = 8});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RiftRadius.full),
      child: Stack(
        children: [
          Container(
            height: height,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          AnimatedFractionallySizedBox(
            duration: RiftMotion.slow,
            curve: RiftMotion.ease,
            widthFactor: value.clamp(0, 1),
            child: Container(
              height: height,
              decoration: const BoxDecoration(gradient: RiftColors.prism),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filet or fin, séparateur de sections.
class GoldRule extends StatelessWidget {
  const GoldRule({super.key, this.width = 48});

  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 2,
    decoration: BoxDecoration(
      gradient: RiftColors.goldGradient,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}
