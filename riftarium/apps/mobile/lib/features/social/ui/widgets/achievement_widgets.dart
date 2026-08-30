import 'package:flutter/material.dart';

import '../../../../app/design/components.dart';
import '../../../../app/theme.dart';
import '../../domain/achievement.dart';

/// Médaillon d'un haut fait : disque au ton de son palier (bronze, argent, or,
/// prisme) avec l'icône du catalogue. Verrouillé, il reste en creux, gris,
/// pour qu'on voie ce qui reste à faire.
class AchievementMedallion extends StatelessWidget {
  const AchievementMedallion({
    super.key,
    required this.achievement,
    this.size = 46,
  });

  final Achievement achievement;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = achievement.isUnlocked;
    final tint = achievementTierColor(achievement.tier);
    final gradient = unlocked
        ? achievementTierGradient(achievement.tier)
        : null;
    final icon = achievementIcon(achievement.icon, family: achievement.family);
    return Semantics(
      label: unlocked
          ? '${achievement.title}, débloqué'
          : '${achievement.title}, verrouillé, ${achievement.progressLabel}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          color: gradient != null
              ? null
              : (unlocked
                    ? tint.withValues(alpha: 0.16)
                    : theme.colorScheme.surfaceContainerHighest),
          border: Border.all(
            color: unlocked
                ? tint.withValues(alpha: 0.55)
                : theme.colorScheme.outline,
            width: 1.5,
          ),
          boxShadow: unlocked ? RiftShadows.soft : null,
        ),
        child: Icon(
          icon,
          size: size * 0.46,
          color: gradient != null
              ? Colors.white
              : (unlocked ? tint : theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Un haut fait dans la liste : médaillon, titre, description, barre de
/// progression et date de déblocage.
class AchievementTile extends StatelessWidget {
  const AchievementTile({super.key, required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final unlocked = achievement.isUnlocked;
    final unlockedAt = achievement.unlockedAt;
    return Opacity(
      opacity: unlocked ? 1 : 0.72,
      child: RiftPanel(
        raised: unlocked,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AchievementMedallion(achievement: achievement, size: 50),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          achievement.title,
                          style: text.displaySmall.copyWith(fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MonoBadge(
                        label: achievementTierLabel(achievement.tier),
                        color: achievementTierColor(achievement.tier),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(achievement.description, style: text.small),
                  const SizedBox(height: 10),
                  PrismBar(value: achievement.progress),
                  const SizedBox(height: 6),
                  Text(
                    unlocked && unlockedAt != null
                        ? 'Débloqué le ${formatSocialDate(unlockedAt)}'
                        : achievement.progressLabel,
                    style: text.mono.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Date courte à la française : `27/08/2026`.
String formatSocialDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
