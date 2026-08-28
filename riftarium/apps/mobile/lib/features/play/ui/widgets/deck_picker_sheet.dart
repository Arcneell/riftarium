import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/components.dart';
import '../../../../app/design/reveal.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../../../app/widgets/common.dart';
import '../../../decks/application/decks_controller.dart';
import '../../../decks/domain/deck.dart';

/// Choix rendu par la feuille : un deck, ou « Sans deck » (`deck` nul).
class DeckChoice {
  const DeckChoice(this.deck);

  final Deck? deck;
}

/// Feuille de choix d'un deck parmi les miens (`GET /decks/mine`).
/// Renvoie null si l'on referme sans choisir.
Future<DeckChoice?> showDeckPicker(BuildContext context) =>
    showModalBottomSheet<DeckChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: RiftColors.inkStrong,
      builder: (context) => Theme(
        data: buildTheme(Brightness.dark),
        child: const FractionallySizedBox(
          heightFactor: 0.8,
          child: _DeckPickerSheet(),
        ),
      ),
    );

class _DeckPickerSheet extends ConsumerWidget {
  const _DeckPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final decks = ref.watch(myDecksProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('MON DECK', style: text.eyebrow),
          const SizedBox(height: 2),
          Text('Choisir un deck', style: text.displaySmall),
          const SizedBox(height: 12),
          Expanded(
            child: decks.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message:
                    'Tes decks n’ont pas pu être chargés. '
                    'Tu peux jouer sans deck et le renseigner plus tard.',
                onRetry: () => ref.invalidate(myDecksProvider),
              ),
              data: (items) => ListView(
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  Reveal(
                    child: RiftPanel(
                      onTap: () =>
                          Navigator.of(context).pop(const DeckChoice(null)),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.block_outlined,
                            size: 20,
                            color: RiftColors.goldSoft,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Sans deck', style: text.bodyStrong),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Text(
                        'Tu n’as pas encore de deck. La partie se suit très '
                        'bien sans : tu pourras en créer un plus tard.',
                        style: text.small,
                      ),
                    ),
                  for (final (index, deck) in items.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Reveal(
                        index: index + 1,
                        child: _DeckRow(deck: deck),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne de la feuille : nom, format et légende du deck.
class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final legend = deck.legend;
    return RiftPanel(
      onTap: () => Navigator.of(context).pop(DeckChoice(deck)),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: legend == null
                ? const Icon(
                    Icons.layers_outlined,
                    color: RiftColors.goldSoft,
                    size: 22,
                  )
                : CardImage(card: legend, thumbWidth: CardArtSize.tile),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyStrong,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    MonoBadge(
                      label: deck.isTournament ? 'Tournoi' : 'Libre',
                      color: deck.isTournament
                          ? RiftColors.gold
                          : RiftColors.hex,
                    ),
                    if (legend != null) MonoBadge(label: legend.name),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
