import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/design/components.dart';
import '../../../../app/design/motion_utils.dart';
import '../../../../app/format.dart';
import '../../../../app/theme.dart';
import '../../domain/achievement.dart';
import 'achievement_icons.dart';

/// Gemme hexagonale d'un haut fait : la forme reprend la gemme hex des
/// impressions alternatives Riftbound, le palier donne le matériau (cuivre,
/// acier, or, prisme irisé animé). Verrouillée, elle reste en creux, grise,
/// pour qu'on voie ce qui reste à faire. Le sens ne repose pas sur la
/// couleur : le libellé du palier est écrit à côté.
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
    final prism = unlocked && achievement.tier == 'prism';
    final material = _gemMaterial(achievement.tier);
    final iconSvg = achievementIconSvg(achievement.key, achievement.icon);

    final Widget face;
    final Color ink;
    final Decoration rim;
    if (!unlocked) {
      rim = BoxDecoration(color: theme.colorScheme.outline);
      face = DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
      );
      ink = theme.colorScheme.onSurfaceVariant;
    } else if (prism) {
      rim = const BoxDecoration(gradient: RiftColors.prism);
      face = _PrismFace(animate: !riftReduceMotion(context));
      ink = Colors.white;
    } else {
      rim = BoxDecoration(gradient: material.rim);
      face = DecoratedBox(
        decoration: BoxDecoration(gradient: material.face),
        // Reflet foil fixe sur l'or, la gemme rare non animée.
        child: achievement.tier == 'gold' ? const _FoilSheen() : null,
      );
      ink = material.ink;
    }

    return Semantics(
      label: unlocked
          ? '${achievement.title}, débloqué'
          : '${achievement.title}, verrouillé, ${achievement.progressLabel}',
      child: SizedBox(
        width: size * 0.9,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(
              clipper: const _HexClipper(),
              child: DecoratedBox(decoration: rim),
            ),
            Padding(
              padding: EdgeInsets.all(size * 0.05),
              child: ClipPath(clipper: const _HexClipper(), child: face),
            ),
            Center(
              child: SvgPicture.string(
                iconSvg,
                width: size * 0.48,
                height: size * 0.48,
                colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Matériau d'un palier : liseré, face et couleur de gravure.
({Gradient rim, Gradient face, Color ink}) _gemMaterial(String tier) =>
    switch (tier) {
      'silver' => (
        rim: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF1F6), Color(0xFF7F8794)],
        ),
        face: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC9CFDA), Color(0xFF8D94A0)],
        ),
        ink: const Color(0xFF263140),
      ),
      'gold' => (
        rim: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFECD394), Color(0xFF7A5D28)],
        ),
        face: RiftColors.goldGradient,
        ink: const Color(0xFFFFF8E4),
      ),
      _ => (
        rim: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD8A468), Color(0xFF7C4F24)],
        ),
        face: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB98A52), Color(0xFF8A5A2C)],
        ),
        ink: const Color(0xFFFFF3E0),
      ),
    };

/// Hexagone pointe en haut, aux proportions de la gemme des cartes.
class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height * 0.25)
    ..lineTo(size.width, size.height * 0.75)
    ..lineTo(size.width / 2, size.height)
    ..lineTo(0, size.height * 0.75)
    ..lineTo(0, size.height * 0.25)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Reflet diagonal discret, comme le foil des cartes.
class _FoilSheen extends StatelessWidget {
  const _FoilSheen();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x00FFFFFF), Color(0x59FFFFFF), Color(0x00FFFFFF)],
        stops: [0.35, 0.5, 0.65],
      ),
    ),
  );
}

/// Face du palier Prisme : dégradé irisé qui tourne lentement, immobile si
/// les animations du système sont réduites.
class _PrismFace extends StatefulWidget {
  const _PrismFace({required this.animate});

  final bool animate;

  @override
  State<_PrismFace> createState() => _PrismFaceState();
}

class _PrismFaceState extends State<_PrismFace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  static const _colors = [
    RiftColors.fury,
    RiftColors.order,
    RiftColors.body,
    RiftColors.calm,
    RiftColors.mind,
    RiftColors.chaos,
    RiftColors.fury,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.animate) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant _PrismFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_spin.isAnimating) _spin.repeat();
    if (!widget.animate && _spin.isAnimating) _spin.stop();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _spin,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: SweepGradient(
          colors: _colors,
          transform: GradientRotation(_spin.value * 2 * math.pi),
        ),
      ),
      child: child,
    ),
    child: const _FoilSheen(),
  );
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
