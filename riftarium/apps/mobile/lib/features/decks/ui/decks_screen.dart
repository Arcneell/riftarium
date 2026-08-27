import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/profile_action.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/decks_controller.dart';
import '../domain/deck.dart';
import '../domain/deck_code.dart';
import 'deck_form_dialogs.dart';
import 'deck_widgets.dart';

/// Onglet « Decks » : bannière, segment « Mes decks | Communauté », création,
/// import d'un code, puis mes decks en boîtes.
class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          PageBanner(
            title: 'Decks',
            art: RiftBanners.decks,
            actions: const [ProfileAction()],
            focus: const Alignment(0, -0.2),
          ),
          const DecksSegment(current: DecksTab.mine),
          if (!signedIn)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 32),
              sliver: SliverToBoxAdapter(
                child: SignInPanel(
                  title: 'Tes decks t’attendent',
                  message:
                      'Connecte-toi pour créer tes decks, les partager et '
                      'suivre ceux que tu aimes. La communauté, elle, reste '
                      'ouverte à tous.',
                  returnTo: AppRoutes.decks,
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: GoldButton(
                        label: 'Nouveau deck',
                        icon: Icons.add,
                        onPressed: () => _createDeck(context, ref),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GhostButton(
                        label: 'Importer un code',
                        icon: Icons.qr_code_2_outlined,
                        onPressed: () => _importCode(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ..._decks(context, ref),
          ],
        ],
      ),
    );
  }

  /// Slivers de la liste : chargement, erreur, invitation ou boîtes de deck.
  List<Widget> _decks(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(myDecksProvider);
    return [
      decks.when(
        loading: () => const SliverFillRemaining(
          hasScrollBody: false,
          child: LoadingView(),
        ),
        error: (error, _) => SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            message: error is ApiException
                ? error.message
                : 'Impossible de charger tes decks.',
            onRetry: () => ref.invalidate(myDecksProvider),
          ),
        ),
        data: (items) => items.isEmpty
            ? SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),
                sliver: SliverToBoxAdapter(
                  child: InvitePanel(
                    icon: Icons.style_outlined,
                    title: 'Construis ton premier deck',
                    message:
                        'Choisis une légende, elle fixe les domaines — le '
                        'reste se joue dans l’éditeur. Un code partagé fait '
                        'aussi l’affaire.',
                    action: GhostButton(
                      label: 'Importer un code',
                      icon: Icons.qr_code_2_outlined,
                      onPressed: () => _importCode(context, ref),
                    ),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final deck = items[index];
                    return Reveal(
                      index: index,
                      child: DeckBox.mine(
                        deck: deck,
                        onOpen: () => context.go(AppRoutes.deck(deck.id)),
                        onDelete: () => _deleteDeck(context, ref, deck),
                      ),
                    );
                  },
                ),
              ),
      ),
    ];
  }

  Future<void> _createDeck(BuildContext context, WidgetRef ref) async {
    final draft = await showDeckDraftDialog(context, title: 'Nouveau deck');
    if (draft == null || !context.mounted) return;
    try {
      final deck = await ref
          .read(deckActionsProvider)
          .create(
            DeckInput(
              name: draft.name,
              description: draft.description,
              format: draft.format,
              isPublic: draft.isPublic,
            ),
          );
      if (!context.mounted) return;
      context.go(AppRoutes.deck(deck.id));
    } on ApiException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Création impossible',
        message: error.message,
      );
    }
  }

  Future<void> _importCode(BuildContext context, WidgetRef ref) async {
    final request = await showImportCodeDialog(context);
    if (request == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final outcome = await ref
          .read(deckActionsProvider)
          .importFromCode(
            request.code,
            name: request.name,
            format: request.format,
            isPublic: request.isPublic,
          );
      if (!context.mounted) return;
      if (outcome.unresolved.isNotEmpty) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              '${outcome.unresolved.length} carte(s) introuvable(s) : '
              '${outcome.unresolved.take(3).join(', ')}',
            ),
          ),
        );
      }
      context.go(AppRoutes.deck(outcome.deck.id));
    } on DeckCodeException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Code illisible',
        message: error.message,
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Import impossible',
        message: error.message,
      );
    }
  }

  Future<void> _deleteDeck(
    BuildContext context,
    WidgetRef ref,
    Deck deck,
  ) async {
    final confirmed = await showAdaptiveMessage(
      context,
      title: 'Supprimer le deck',
      message:
          'Le deck « ${deck.name} » sera supprimé pour de bon — impossible de '
          'le récupérer ensuite.',
      closeLabel: 'Annuler',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(deckActionsProvider).delete(deck.id);
    } on ApiException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Suppression impossible',
        message: error.message,
      );
    }
  }
}
