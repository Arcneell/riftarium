import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../../core/config.dart';
import '../../auth/application/auth_controller.dart';
import '../application/decks_controller.dart';
import '../domain/deck.dart';
import '../domain/deck_code.dart';
import '../domain/deck_rules.dart';
import '../domain/deck_share.dart';
import 'deck_editor_screen.dart';
import 'deck_widgets.dart';

/// Fiche d'un deck : en-tête, légalité, cartes par zone, partage et actions.
class DeckDetailScreen extends ConsumerStatefulWidget {
  const DeckDetailScreen({super.key, required this.deckId});

  final int deckId;

  @override
  ConsumerState<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends ConsumerState<DeckDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Statistique de visite : lancée après le premier rendu, sans rien bloquer.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deckActionsProvider).recordView(widget.deckId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(deckProvider(widget.deckId));
    final handle = ref.watch(
      authControllerProvider.select((state) => state.profile?.handle),
    );

    return AdaptiveScaffold(
      title: deck.valueOrNull?.name ?? 'Deck',
      body: deck.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is ApiException
              ? error.message
              : 'Impossible de charger ce deck.',
          onRetry: () => ref.invalidate(deckProvider(widget.deckId)),
        ),
        data: (value) => _DeckBody(deck: value, isOwner: value.owner == handle),
      ),
    );
  }
}

class _DeckBody extends ConsumerWidget {
  const _DeckBody({required this.deck, required this.isOwner});

  final Deck deck;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final groups = groupDeck(deck.cards);
    final price = formatEur(deck.totalEur);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DeckCover(legend: deck.legend, width: 84),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deck.name, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text('par ${deck.owner}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DeckLegalBadge.forDeck(deck),
                      Text(
                        deck.isPublic ? 'public' : 'privé',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (deck.isPending)
                        Text('en modération', style: theme.textTheme.bodySmall),
                      if (price != null)
                        Text(price, style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      DeckStat(
                        icon: deck.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_outline,
                        value: deck.likes,
                        active: deck.likedByMe,
                        onPressed: deck.isShareable
                            ? () => _toggleLike(context, ref)
                            : null,
                        semanticLabel: deck.likedByMe
                            ? 'Ne plus aimer'
                            : 'Aimer ce deck',
                      ),
                      const SizedBox(width: 12),
                      DeckStat(
                        icon: Icons.visibility_outlined,
                        value: deck.views,
                        semanticLabel: '${deck.views} vue(s)',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (deck.description != null && deck.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(deck.description!, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 16),
        _Checks(deck: deck),
        const SizedBox(height: 16),
        _Actions(deck: deck, isOwner: isOwner),
        const SizedBox(height: 8),
        for (final zone in deckZones)
          if (groups[zone.key]!.isNotEmpty)
            _ZoneSection(zone: zone, entries: groups[zone.key]!),
        if (deck.cards.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: EmptyView(
              title: 'Deck vide',
              detail: 'Ouvre l’éditeur pour ajouter des cartes.',
              icon: Icons.style_outlined,
            ),
          ),
      ],
    );
  }

  Future<void> _toggleLike(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(deckActionsProvider).toggleLike(deck.id);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Action impossible',
        message: error.message,
      );
    }
  }
}

/// Résultat de la validation de tournoi calculée par l'API (`deck.checks`).
class _Checks extends StatelessWidget {
  const _Checks({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!deck.isTournament) {
      return Text(
        'Format libre : les règles officielles ne sont pas vérifiées.',
        style: theme.textTheme.bodyMedium,
      );
    }
    if (deck.checks.isEmpty) {
      return Text('Deck légal', style: theme.textTheme.titleSmall);
    }
    final problems = deck.checks.where((check) => !check.ok).toList();
    if (problems.isEmpty) {
      return Row(
        children: [
          Icon(Icons.verified_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('Deck légal', style: theme.textTheme.titleSmall),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('À corriger', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final check in problems)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(check.message, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.deck, required this.isOwner});

  final Deck deck;
  final bool isOwner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (isOwner)
          OutlinedButton.icon(
            onPressed: () => _edit(context),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Éditer'),
          ),
        if (isOwner)
          OutlinedButton.icon(
            onPressed: () => _showMissing(context),
            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
            label: const Text('Cartes manquantes'),
          ),
        if (signedIn && !isOwner)
          OutlinedButton.icon(
            onPressed: () => _copy(context, ref),
            icon: const Icon(Icons.copy_all_outlined, size: 18),
            label: const Text('Copier dans mes decks'),
          ),
        OutlinedButton.icon(
          onPressed: () => _copyCode(context),
          icon: const Icon(Icons.tag_outlined, size: 18),
          label: const Text('Copier le code'),
        ),
        OutlinedButton.icon(
          onPressed: () => _share(context),
          icon: const Icon(Icons.ios_share, size: 18),
          label: const Text('Partager'),
        ),
      ],
    );
  }

  void _edit(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DeckEditorScreen(deck: deck)),
    );
  }

  void _showMissing(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DeckMissingSheet(deckId: deck.id),
    );
  }

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    try {
      final copy = await ref.read(deckActionsProvider).copy(deck.id);
      if (!context.mounted) return;
      context.go(AppRoutes.deck(copy.id));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Copie impossible',
        message: error.message,
      );
    }
  }

  Future<void> _copyCode(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Clipboard.setData(ClipboardData(text: deckCodeOf(deck.cards)));
      messenger?.showSnackBar(
        const SnackBar(content: Text('Code copié dans le presse-papiers')),
      );
    } on DeckCodeException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Code indisponible',
        message: error.message,
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    final lines = <String>[deck.name];
    try {
      lines.add(deckCodeOf(deck.cards));
    } on DeckCodeException {
      // Deck vide : on partage au moins le lien.
    }
    if (deck.isShareable) {
      lines.add('${AppConfig.webBaseUrl}/decks/${deck.id}');
    }
    await SharePlus.instance.share(
      ShareParams(text: lines.join('\n'), subject: deck.name),
    );
  }
}

/// Liste d'achats du deck (`GET /api/decks/{id}/missing`).
class DeckMissingSheet extends ConsumerWidget {
  const DeckMissingSheet({super.key, required this.deckId});

  final int deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(deckMissingProvider(deckId));
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: missing.when(
          loading: () => const SizedBox(height: 160, child: LoadingView()),
          error: (error, _) => SizedBox(
            height: 160,
            child: ErrorView(
              message: error is ApiException
                  ? error.message
                  : 'Analyse impossible.',
              onRetry: () => ref.invalidate(deckMissingProvider(deckId)),
            ),
          ),
          data: (value) => value.items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Tu possèdes déjà toutes les cartes de ce deck. Bon match !',
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cartes manquantes',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Il te manque ${value.missingTotal} carte(s) sur les '
                      '${value.deckTotal} du deck.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: value.items.length,
                        itemBuilder: (context, index) {
                          final item = value.items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CardImage(card: item.card, width: 36),
                            title: Text(item.card.name),
                            subtitle: Text(
                              '${item.missing} à trouver · '
                              '${item.owned}/${item.needed} en collection',
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              context.go(AppRoutes.card(item.card.id));
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Une zone du deck : titre, compteur et vignettes des cartes.
class _ZoneSection extends StatelessWidget {
  const _ZoneSection({required this.zone, required this.entries});

  final DeckZone zone;
  final List<DeckCard> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = entries.fold<int>(0, (total, entry) => total + entry.qty);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${zone.label} · $count/${zone.target}${zone.key == 'main' ? '+' : ''}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in entries) _DeckCardTile(entry: entry),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeckCardTile extends StatelessWidget {
  const _DeckCardTile({required this.entry});

  final DeckCard entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = entry.card.isLandscape ? 132.0 : 84.0;
    return InkWell(
      onTap: () => context.go(AppRoutes.card(entry.card.id)),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CardImage(card: entry.card, width: width),
                if (entry.qty > 1)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '×${entry.qty}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.card.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
