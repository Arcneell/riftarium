import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/collection_controller.dart';
import '../domain/collection.dart';
import 'widgets/collection_edit_sheet.dart';

/// Onglet Collection : résumé, progression par set, recherche et cartes
/// possédées. Toute modification passe par la feuille d'édition.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final _search = TextEditingController();
  bool _progressOpen = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(
      () =>
          ref.read(collectionControllerProvider.notifier).search(_search.text),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(collectionProgressProvider);
    await ref.read(collectionControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(
      authControllerProvider.select((auth) => auth.isSignedIn),
    );
    if (!signedIn) {
      return const SignInRequired(
        title: 'Collection',
        message:
            'Connecte-toi pour suivre ton inventaire, ta wishlist et ta progression par set.',
      );
    }

    final collection = ref.watch(collectionControllerProvider);
    final state = collection.valueOrNull;
    Widget body;
    if (state == null) {
      body = collection.hasError
          ? _Scrollable(
              child: ErrorView(
                message: messageOf(collection.error),
                onRetry: _refresh,
              ),
            )
          : const LoadingView();
    } else {
      body = _CollectionBody(
        state: state,
        search: _search,
        progressOpen: _progressOpen,
        onToggleProgress: () => setState(() => _progressOpen = !_progressOpen),
      );
    }

    return AdaptiveScaffold(
      title: 'Collection',
      body: RefreshIndicator.adaptive(onRefresh: _refresh, child: body),
    );
  }
}

/// Message affichable d'une erreur de provider : les appels API lèvent des
/// [ApiException] dont le message est déjà en français.
String messageOf(Object? error) => error is ApiException
    ? error.message
    : 'Contenu indisponible pour le moment.';

class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.symmetric(vertical: 48),
    children: [child],
  );
}

class _CollectionBody extends ConsumerWidget {
  const _CollectionBody({
    required this.state,
    required this.search,
    required this.progressOpen,
    required this.onToggleProgress,
  });

  final CollectionState state;
  final TextEditingController search;
  final bool progressOpen;
  final VoidCallback onToggleProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const padding = 16.0;
        final width = constraints.maxWidth - padding * 2;
        final columns = (width / 170).ceil().clamp(2, 6);
        final tileWidth = (width - spacing * (columns - 1)) / columns;
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(padding, 16, padding, 0),
              sliver: SliverToBoxAdapter(
                child: _Header(
                  state: state,
                  search: search,
                  progressOpen: progressOpen,
                  onToggleProgress: onToggleProgress,
                ),
              ),
            ),
            if (state.items.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: EmptyView(
                    title: state.isEmpty
                        ? 'Ta collection est vide'
                        : 'Aucune carte ne correspond',
                    detail: state.isEmpty
                        ? 'Ouvre une fiche carte et indique combien d’exemplaires tu possèdes.'
                        : 'Essaie un autre nom, un code (ogn-202) ou un type.',
                    icon: Icons.style_outlined,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(padding),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                    mainAxisExtent: tileWidth / CardImage.portraitRatio + 62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _CollectionTile(item: state.items[index]),
                    childCount: state.items.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(padding, 0, padding, 32),
                child: state.hasMore
                    ? Center(
                        child: AdaptiveTextButton(
                          label: state.loadingMore
                              ? 'Chargement…'
                              : 'Charger la suite',
                          onPressed: state.loadingMore
                              ? null
                              : () => ref
                                    .read(collectionControllerProvider.notifier)
                                    .loadMore(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.state,
    required this.search,
    required this.progressOpen,
    required this.onToggleProgress,
  });

  final CollectionState state;
  final TextEditingController search;
  final bool progressOpen;
  final VoidCallback onToggleProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(collectionProgressProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Cartes différentes',
                value: '${state.uniqueCards}',
              ),
            ),
            Expanded(
              child: _Stat(label: 'Exemplaires', value: '${state.totalCards}'),
            ),
            Expanded(
              child: _Stat(
                label: 'Valeur estimée',
                value: formatEur(state.valueEur) ?? '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            AdaptiveTextButton(
              label: 'Wishlist',
              onPressed: () => context.go(AppRoutes.wishlist),
            ),
            AdaptiveTextButton(
              label: 'Scanner',
              onPressed: () => context.push(AppRoutes.scan),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AdaptiveTextField(
          controller: search,
          label: 'Rechercher dans ma collection',
          placeholder: 'Jinx, ogn-202, reaction…',
          autocorrect: false,
          textInputAction: TextInputAction.search,
        ),
        if (progress != null && !progress.isEmpty) ...[
          const SizedBox(height: 12),
          _ProgressSection(
            progress: progress,
            open: progressOpen,
            onToggle: onToggleProgress,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '${state.total} carte(s) unique(s)',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Progression par set, repliée par défaut : consultable sans encombrer.
class _ProgressSection extends StatelessWidget {
  const _ProgressSection({
    required this.progress,
    required this.open,
    required this.onToggle,
  });

  final CollectionProgress progress;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final overall = progress.overall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Icon(open ? Icons.expand_less : Icons.expand_more, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Progression par set — ${overall.owned}/${overall.total} · ${overall.percent} %',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (open) ...[
          const SizedBox(height: 8),
          _ProgressRow(row: overall),
          for (final row in progress.sets) _ProgressRow(row: row),
        ],
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.row});

  final SetCompletion row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.name, style: theme.textTheme.bodyMedium),
              ),
              Text(
                '${row.owned}/${row.total} · ${row.percent} %',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: row.ratio,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 2),
          Text(row.missingLabel, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Une carte possédée : visuel, nom, code et pastille de quantité (qui ouvre
/// l'édition). L'appui long ouvre aussi l'édition.
class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.item});

  final CollectionItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = formatEur(item.valueEur);
    return GestureDetector(
      onTap: () => context.go(AppRoutes.card(item.card.id)),
      onLongPress: () => showCollectionEditor(context, item.card.id),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: CardImage(card: item.card)),
          const SizedBox(height: 4),
          Text(
            item.card.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.card.displayCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (value != null) Text(value, style: theme.textTheme.bodySmall),
            ],
          ),
          Semantics(
            button: true,
            label: 'Modifier ${item.card.name}',
            child: GestureDetector(
              onTap: () => showCollectionEditor(context, item.card.id),
              behavior: HitTestBehavior.opaque,
              child: Text(
                '×${item.totalQty} · ${item.entriesLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
