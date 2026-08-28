import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/ui/login_screen.dart' show BannerBackButton;
import '../application/play_providers.dart';
import '../domain/play_stats.dart';

/// Statistiques de mes parties suivies. Seules les parties confirmées par les
/// deux joueurs (et les abandons) y entrent : une partie contestée reste dans
/// l'historique mais ne compte nulle part ici.
class PlayStatsScreen extends ConsumerWidget {
  const PlayStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(playStatsProvider);
    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(playStatsProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            PageBanner(
              title: 'Statistiques',
              eyebrow: 'Mes parties',
              art: RiftBanners.decks,
              expandedHeight: 190,
              leading: context.canPop()
                  ? BannerBackButton(onPressed: context.pop)
                  : null,
            ),
            ...stats.when(
              loading: () => const [
                SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
              ],
              error: (error, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message: error is ApiException
                        ? error.message
                        : 'Tes statistiques n’ont pas pu être chargées.',
                    onRetry: () => ref.invalidate(playStatsProvider),
                  ),
                ),
              ],
              data: (data) => _content(context, data),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, PlayStats stats) {
    if (stats.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            title: 'Rien à compter pour l’instant',
            detail:
                'Joue une partie suivie et fais confirmer le résultat : tes '
                'statistiques se rempliront toutes seules.',
            icon: Icons.insights_outlined,
            action: GoldButton(
              label: 'Jouer une partie suivie',
              icon: Icons.wifi_tethering_rounded,
              expand: false,
              onPressed: () => context.push(AppRoutes.trackedPlay),
            ),
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        sliver: SliverToBoxAdapter(
          child: Reveal(child: _Totals(totals: stats.totals)),
        ),
      ),
      if (stats.recent.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: SectionTitle(eyebrow: 'Rythme', title: '30 derniers jours'),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(child: _RecentChart(days: stats.recent)),
        ),
      ],
      if (stats.byFormat.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: SectionTitle(eyebrow: 'Formats', title: 'Par format'),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverToBoxAdapter(
            child: RiftPanel(
              child: Column(
                children: [
                  for (final (index, format) in stats.byFormat.indexed) ...[
                    if (index > 0) const SizedBox(height: 12),
                    _Bar(
                      title: format.label,
                      won: format.won,
                      lost: format.lost,
                      played: format.played,
                      ratio: format.played == 0
                          ? 0
                          : format.won / format.played,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
      if (stats.byDeck.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: SectionTitle(eyebrow: 'Constructions', title: 'Par deck'),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverList.separated(
            itemCount: stats.byDeck.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final deck = stats.byDeck[index];
              return Reveal(
                index: index,
                child: RiftPanel(
                  child: _Bar(
                    title: deck.name,
                    subtitle: deck.format == 'free' ? 'Libre' : 'Tournoi',
                    won: deck.won,
                    lost: deck.lost,
                    played: deck.played,
                    ratio: deck.winRatio,
                  ),
                ),
              );
            },
          ),
        ),
      ],
      if (stats.byLegend.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: SectionTitle(eyebrow: 'Champions', title: 'Par légende'),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverList.separated(
            itemCount: stats.byLegend.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => Reveal(
              index: index,
              child: _LegendRow(legend: stats.byLegend[index]),
            ),
          ),
        ),
      ],
      if (stats.byOpponentLegend.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: SectionTitle(eyebrow: 'En face', title: 'Légendes affrontées'),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          sliver: SliverList.separated(
            itemCount: stats.byOpponentLegend.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) => Reveal(
              index: index,
              child: _LegendRow(legend: stats.byOpponentLegend[index]),
            ),
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }
}

/// Les compteurs généraux, en tête : joués, gagnés, perdus, taux, séries.
class _Totals extends StatelessWidget {
  const _Totals({required this.totals});

  final PlayTotals totals;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      raised: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Tile(value: '${totals.played}', label: 'Joués'),
              _Tile(
                value: '${totals.won}',
                label: 'Gagnés',
                color: RiftColors.calm,
              ),
              _Tile(
                value: '${totals.lost}',
                label: 'Perdus',
                color: RiftColors.fury,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Taux de victoire', style: text.small),
              const Spacer(),
              Text(totals.winRateLabel, style: text.monoStrong),
            ],
          ),
          const SizedBox(height: 8),
          PrismBar(value: totals.winRatio, height: 10),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MonoBadge(label: 'Série ${totals.currentStreak}'),
              MonoBadge(label: 'Meilleure ${totals.bestStreak}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: text.displayMedium.copyWith(color: color ?? RiftColors.gold),
          ),
          const SizedBox(height: 2),
          Text(label, style: text.small.copyWith(fontSize: 12.5)),
        ],
      ),
    );
  }
}

/// Une ligne « victoires / défaites » avec sa barre de proportion.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.title,
    required this.won,
    required this.lost,
    required this.played,
    required this.ratio,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final int won;
  final int lost;
  final int played;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyStrong,
              ),
            ),
            const SizedBox(width: 8),
            Text('$won V – $lost D', style: text.mono),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: text.small.copyWith(fontSize: 12)),
        ],
        const SizedBox(height: 8),
        _WinBar(ratio: played == 0 ? 0 : ratio),
      ],
    );
  }
}

/// Barre or (victoires) sur fond encre (défaites) : la proportion se lit sans
/// chiffre, la teinte reste celle de la charte.
class _WinBar extends StatelessWidget {
  const _WinBar({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RiftRadius.full),
      child: Stack(
        children: [
          Container(
            height: 8,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          AnimatedFractionallySizedBox(
            duration: RiftMotion.slow,
            curve: RiftMotion.ease,
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: RiftColors.goldGradient,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.legend});

  final LegendStat legend;

  @override
  Widget build(BuildContext context) {
    final url = legend.imageUrl;
    return RiftPanel(
      child: Row(
        children: [
          SizedBox(
            width: 34,
            height: 47,
            child: url == null || url.isEmpty
                ? const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: RiftColors.gold,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(RiftRadius.card),
                    child: CachedNetworkImage(
                      imageUrl: cardThumb(url, width: CardArtSize.tile),
                      cacheManager: riftImageCache,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) =>
                          const SizedBox.shrink(),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Bar(
              title: legend.name,
              won: legend.won,
              lost: legend.lost,
              played: legend.played,
              ratio: legend.winRatio,
            ),
          ),
        ],
      ),
    );
  }
}

/// Trente colonnes, une par jour : la hauteur donne les parties jouées, la
/// part dorée les victoires. Rien d'autre — c'est un rythme, pas un tableau.
class _RecentChart extends StatelessWidget {
  const _RecentChart({required this.days});

  final List<DayStat> days;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final played = days.fold<int>(0, (sum, day) => sum + day.played);
    final won = days.fold<int>(0, (sum, day) => sum + day.won);
    return RiftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('$played partie(s)', style: text.bodyStrong),
              const Spacer(),
              Text('$won gagnée(s)', style: text.mono),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: CustomPaint(
              painter: RecentPlayPainter(
                days: days,
                base: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

/// Peintre de l'histogramme des trente derniers jours.
class RecentPlayPainter extends CustomPainter {
  const RecentPlayPainter({required this.days, required this.base});

  final List<DayStat> days;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final maxPlayed = days
        .map((day) => day.played)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final slot = size.width / days.length;
    final width = (slot * 0.62).clamp(2.0, 12.0);
    final radius = Radius.circular(width / 2);
    final playedPaint = Paint()..color = base;
    final wonPaint = Paint()..color = RiftColors.gold;

    for (final (index, day) in days.indexed) {
      final left = slot * index + (slot - width) / 2;
      final height = day.played == 0
          ? 2.0
          : (day.played / maxPlayed) * size.height;
      final top = size.height - height;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, width, height),
          radius,
        ),
        playedPaint,
      );
      if (day.won > 0) {
        final wonHeight = height * (day.won / day.played);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, size.height - wonHeight, width, wonHeight),
            radius,
          ),
          wonPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(RecentPlayPainter oldDelegate) =>
      oldDelegate.days != days || oldDelegate.base != base;
}
