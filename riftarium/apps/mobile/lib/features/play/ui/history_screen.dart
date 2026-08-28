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
import '../domain/history.dart';
import 'widgets/play_avatar.dart';

/// Mes parties suivies terminées : l'adversaire, les légendes, les decks, le
/// score et l'issue. Les parties contestées restent visibles ici même si elles
/// ne comptent pas dans les statistiques.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(historyProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            PageBanner(
              title: 'Historique',
              eyebrow: 'Mes parties',
              art: RiftBanners.community,
              expandedHeight: 190,
              leading: context.canPop()
                  ? BannerBackButton(onPressed: context.pop)
                  : null,
            ),
            ...history.when(
              loading: () => const [
                SliverFillRemaining(hasScrollBody: false, child: LoadingView()),
              ],
              error: (error, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    message: error is ApiException
                        ? error.message
                        : 'Tes parties n’ont pas pu être chargées.',
                    onRetry: () => ref.invalidate(historyProvider),
                  ),
                ),
              ],
              data: (page) => _content(context, page),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, HistoryPage page) {
    if (page.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            title: 'Aucune partie suivie',
            detail:
                'Lance une partie suivie : le score, les decks et le résultat '
                'seront gardés ici.',
            icon: Icons.history_rounded,
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
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        sliver: SliverList.separated(
          itemCount: page.items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) => Reveal(
            index: index,
            child: _HistoryTile(item: page.items[index]),
          ),
        ),
      ),
    ];
  }
}

/// Une ligne d'historique : l'adversaire au centre, l'issue en couleur à
/// droite, les légendes en vignettes de part et d'autre du score.
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final HistoryItem item;

  /// Vert calme pour une victoire, rouge fureur pour une défaite, gris muet
  /// pour un résultat contesté (il ne compte pas).
  Color _color(RiftTextStyles text) => switch (item.outcome) {
    'win' => RiftColors.calm,
    'loss' => RiftColors.fury,
    _ => text.muted,
  };

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final color = _color(text);
    final decks = [
      if (item.myDeck != null) item.myDeck!.name,
      if (item.opponentDeck != null) item.opponentDeck!.name,
    ];
    return RiftPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                // Le pseudo de l'adversaire mène à son profil public.
                child: PressScale(
                  onTap: (item.opponent?.handle ?? '').isEmpty
                      ? null
                      : () => context.push(
                          AppRoutes.player(item.opponent!.handle),
                        ),
                  child: Row(
                    children: [
                      PlayAvatar(user: item.opponent, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.opponent?.displayName ?? 'Joueur retiré',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.title,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                item.modeLabel,
                                if (item.playedAt != null)
                                  _date(item.playedAt!),
                                if (item.status == 'abandoned') 'abandon',
                              ].join(' · '),
                              style: text.small.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.scoreLabel,
                    style: text.monoStrong.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  MonoBadge(label: item.outcomeLabel, color: color),
                ],
              ),
            ],
          ),
          if (item.myLegend != null ||
              item.opponentLegend != null ||
              decks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (item.myLegend != null) ...[
                  SizedBox(
                    width: 26,
                    child: CardImage(
                      card: item.myLegend!,
                      thumbWidth: CardArtSize.tile,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text('vs', style: text.mono),
                const SizedBox(width: 8),
                if (item.opponentLegend != null) ...[
                  SizedBox(
                    width: 26,
                    child: CardImage(
                      card: item.opponentLegend!,
                      thumbWidth: CardArtSize.tile,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    decks.isEmpty ? 'Sans deck' : decks.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: text.small.copyWith(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}
