import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../auth/ui/login_screen.dart' show BannerBackButton;
import '../application/social_providers.dart';
import '../domain/achievement.dart';
import 'widgets/achievement_widgets.dart';
import 'widgets/social_widgets.dart';

/// Mes hauts faits : le catalogue entier, famille par famille. Les débloqués
/// passent devant ; les autres montrent ce qu'il reste à faire.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(myAchievementsProvider);
    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(myAchievementsProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            PageBanner(
              title: 'Hauts faits',
              eyebrow: 'Mon profil',
              art: RiftBanners.rules,
              expandedHeight: 190,
              leading: context.canPop()
                  ? BannerBackButton(onPressed: context.pop)
                  : null,
            ),
            ...achievements.when(
              loading: () => const [
                SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
              ],
              error: (error, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message: socialErrorMessage(
                      error,
                      fallback: 'Tes hauts faits n’ont pas pu être chargés.',
                    ),
                    onRetry: () => ref.invalidate(myAchievementsProvider),
                  ),
                ),
              ],
              data: (items) => _content(items),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(List<Achievement> items) {
    if (items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            title: 'Rien à décrocher pour l’instant',
            detail: 'Joue une partie suivie pour débloquer les premiers.',
            icon: Icons.military_tech,
          ),
        ),
      ];
    }
    final unlocked = items.where((item) => item.isUnlocked).length;
    final families = <String>[
      ...achievementFamilies.where(
        (family) => items.any((item) => item.family == family),
      ),
      ...{
        for (final item in items)
          if (!achievementFamilies.contains(item.family)) item.family,
      },
    ];

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        sliver: SliverToBoxAdapter(
          child: Reveal(
            child: _Summary(unlocked: unlocked, total: items.length),
          ),
        ),
      ),
      for (final family in families) ...[
        SliverToBoxAdapter(
          child: SectionTitle(
            eyebrow: 'Famille',
            title: achievementFamilyLabel(family),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: _FamilyList(items: _ofFamily(items, family)),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 36)),
    ];
  }

  /// Les hauts faits d'une famille, débloqués d'abord (du plus récent au plus
  /// ancien), puis les autres du plus avancé au moins avancé.
  static List<Achievement> _ofFamily(List<Achievement> items, String family) {
    final list = items.where((item) => item.family == family).toList()
      ..sort((a, b) {
        if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
        if (a.isUnlocked && b.isUnlocked) {
          return b.unlockedAt!.compareTo(a.unlockedAt!);
        }
        return b.progress.compareTo(a.progress);
      });
    return list;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      raised: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DÉBLOQUÉS', style: text.eyebrow),
          const SizedBox(height: 6),
          Text(
            '$unlocked sur $total',
            style: text.displayMedium.copyWith(color: RiftColors.gold),
          ),
          const SizedBox(height: 10),
          PrismBar(value: total == 0 ? 0 : unlocked / total),
        ],
      ),
    );
  }
}

class _FamilyList extends StatelessWidget {
  const _FamilyList({required this.items});

  final List<Achievement> items;

  @override
  Widget build(BuildContext context) => SliverList.separated(
    itemCount: items.length,
    separatorBuilder: (context, index) => const SizedBox(height: 10),
    itemBuilder: (context, index) => Reveal(
      index: index,
      child: AchievementTile(achievement: items[index]),
    ),
  );
}
