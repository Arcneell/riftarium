import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/components.dart';
import '../../../../app/design/reveal.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../../../app/widgets/common.dart';
import '../../../cards/domain/card.dart';
import '../../application/game_providers.dart';
import '../../data/legends_repository.dart';

/// Feuille de choix d'une légende. Renvoie la carte retenue, ou null si
/// l'utilisateur referme sans choisir.
Future<RiftCard?> showLegendPicker(BuildContext context) =>
    showModalBottomSheet<RiftCard>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: RiftColors.inkStrong,
      builder: (context) => Theme(
        data: buildTheme(Brightness.dark),
        child: const FractionallySizedBox(
          heightFactor: 0.92,
          child: _LegendPickerSheet(),
        ),
      ),
    );

class _LegendPickerSheet extends ConsumerStatefulWidget {
  const _LegendPickerSheet();

  @override
  ConsumerState<_LegendPickerSheet> createState() => _LegendPickerSheetState();
}

class _LegendPickerSheetState extends ConsumerState<_LegendPickerSheet> {
  final _search = TextEditingController();
  String _query = '';
  LegendGroup? _opened;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final legends = ref.watch(legendsProvider);
    final opened = _opened;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (opened != null)
                IconButton(
                  onPressed: () => setState(() => _opened = null),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Toutes les légendes',
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opened == null ? 'LÉGENDES' : 'VARIANTES',
                      style: text.eyebrow,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      opened?.name ?? 'Choisir sa légende',
                      style: text.displaySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (opened == null)
            TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Rechercher une légende',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: opened != null
                ? _Variants(group: opened)
                : legends.when(
                    loading: () => const LoadingView(),
                    error: (error, _) => ErrorView(
                      message:
                          'Les légendes n’ont pas pu être chargées. '
                          'Sans réseau ni copie locale, saisis simplement les '
                          'noms des joueurs.',
                      onRetry: () => ref.invalidate(legendsProvider),
                    ),
                    data: (groups) => _Grid(
                      groups: groups
                          .where((group) => group.matches(_query))
                          .toList(),
                      onOpen: (group) => group.variants.length == 1
                          ? Navigator.of(context).pop(group.base)
                          : setState(() => _opened = group),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.groups, required this.onOpen});

  final List<LegendGroup> groups;
  final void Function(LegendGroup group) onOpen;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const EmptyView(
        title: 'Aucune légende',
        detail: 'Essaie un autre nom.',
        icon: Icons.search_off_outlined,
      );
    }
    final columns = MediaQuery.sizeOf(context).width < 340 ? 2 : 3;
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 14,
        childAspectRatio: 0.58,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Reveal(
          index: index,
          child: PressScale(
            onTap: () => onOpen(group),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CardImage(
                          card: group.base,
                          thumbWidth: CardArtSize.tile,
                          shadow: true,
                        ),
                      ),
                      if (group.variants.length > 1)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: MonoBadge(
                            label: '${group.variants.length} versions',
                            filled: true,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: riftText(context).small.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Variants extends StatelessWidget {
  const _Variants({required this.group});

  final LegendGroup group;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 0.6,
      ),
      itemCount: group.variants.length,
      itemBuilder: (context, index) {
        final card = group.variants[index];
        final label = legendVariantLabel(card);
        return Reveal(
          index: index,
          child: PressScale(
            onTap: () => Navigator.of(context).pop(card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CardImage(
                    card: card,
                    thumbWidth: CardArtSize.tile,
                    foil: label != null,
                    shadow: true,
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: MonoBadge(label: label ?? 'Normale')),
                const SizedBox(height: 4),
                Text(
                  card.displayCode,
                  textAlign: TextAlign.center,
                  style: text.mono.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
