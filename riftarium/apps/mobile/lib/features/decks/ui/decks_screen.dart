import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/adaptive.dart';
import '../../../app/router.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../application/decks_controller.dart';
import '../domain/deck.dart';
import '../domain/deck_code.dart';
import 'deck_form_dialogs.dart';
import 'deck_widgets.dart';

/// Onglet « Decks » : mes decks, création, import d'un code, communauté.
class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    if (!signedIn) return const _SignedOut();

    final decks = ref.watch(myDecksProvider);
    return AdaptiveScaffold(
      title: 'Mes decks',
      trailing: IconButton(
        tooltip: 'Communauté',
        icon: const Icon(Icons.groups_outlined),
        onPressed: () => context.go(AppRoutes.community),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: AdaptiveFilledButton(
                    label: 'Nouveau deck',
                    onPressed: () => _createDeck(context, ref),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AdaptiveTextButton(
                    label: 'Importer un code',
                    onPressed: () => _importCode(context, ref),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: decks.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: error is ApiException
                    ? error.message
                    : 'Impossible de charger tes decks.',
                onRetry: () => ref.invalidate(myDecksProvider),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyView(
                      title: 'Aucun deck pour l’instant',
                      detail:
                          'Crée ton premier deck, ou importe un code partagé.',
                      icon: Icons.style_outlined,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final deck = items[index];
                        return MyDeckTile(
                          deck: deck,
                          onOpen: () => context.go(AppRoutes.deck(deck.id)),
                          onDelete: () => _deleteDeck(context, ref, deck),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
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

/// Sans session : l'invite de connexion, plus l'accès libre à la communauté.
class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: SignInRequired(
            title: 'Decks',
            message:
                'Connecte-toi pour créer tes decks, les partager et suivre '
                'ceux que tu aimes.',
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdaptiveTextButton(
              label: 'Voir la communauté',
              onPressed: () => context.go(AppRoutes.community),
            ),
          ),
        ),
      ],
    );
  }
}
