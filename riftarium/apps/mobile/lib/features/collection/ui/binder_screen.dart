import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../cards/domain/card.dart';
import '../application/binder_providers.dart';
import '../application/collection_controller.dart';
import '../domain/collection.dart';
import 'widgets/collection_sign_in.dart';

/// Le classeur : les cartes d'un set rangées dans des pochettes 3 × 3, page
/// après page, comme un vrai classeur de collectionneur. Les cartes possédées
/// brillent, les manquantes sont des fantômes gris — avec leur code et leur
/// prix, pour donner envie de les trouver. On tourne les pages en glissant
/// le doigt, avec un pivotement de feuille.
class BinderScreen extends ConsumerStatefulWidget {
  const BinderScreen({super.key});

  @override
  ConsumerState<BinderScreen> createState() => _BinderScreenState();
}

class _BinderScreenState extends ConsumerState<BinderScreen> {
  final _controller = PageController();
  int _current = 0;

  @override
  void initState() {
    super.initState();
    // Set ouvert par défaut : le premier incomplet — celui qu'on veut finir.
    unawaited(_pickDefaultSet());
  }

  Future<void> _pickDefaultSet() async {
    try {
      final progress = await ref.read(collectionProgressProvider.future);
      if (!mounted || progress.sets.isEmpty) return;
      if (ref.read(binderSetProvider) != null) return;
      final first = progress.sets.firstWhere(
        (row) => row.missing > 0,
        orElse: () => progress.sets.first,
      );
      ref.read(binderSetProvider.notifier).state = first.setId;
    } on Exception {
      // L'erreur de progression est déjà affichée par le corps de l'écran.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _backToFirstPage() {
    setState(() => _current = 0);
    if (_controller.hasClients) _controller.jumpToPage(0);
  }

  void _selectSet(String setId) {
    if (ref.read(binderSetProvider) == setId) return;
    ref.read(binderSetProvider.notifier).state = setId;
    _backToFirstPage();
  }

  void _setFilter(String? owned) {
    if (ref.read(binderOwnedProvider) == owned) return;
    ref.read(binderOwnedProvider.notifier).state = owned;
    _backToFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isSignedIn) {
      return const CollectionSignIn(
        title: 'Classeur',
        eyebrow: 'Collection',
        message: 'Connecte-toi pour feuilleter ton classeur.',
        returnTo: AppRoutes.binder,
      );
    }

    final progressAsync = ref.watch(collectionProgressProvider);
    final progress = progressAsync.valueOrNull;
    final setId = ref.watch(binderSetProvider);
    final owned = ref.watch(binderOwnedProvider);
    SetCompletion? selected;
    if (setId != null && progress != null) {
      for (final row in progress.sets) {
        if (row.setId == setId) {
          selected = row;
          break;
        }
      }
    }

    // Nombre de doubles pages : connu dès que la première page est chargée.
    final firstPage = setId == null
        ? null
        : ref.watch(binderPageProvider((setId: setId, owned: owned, page: 1)));
    final total = firstPage?.valueOrNull?.total ?? 0;
    final pages = math.max(1, (total / binderPageSize).ceil());

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onBack: () => context.pop()),
            if (progress != null && progress.sets.isNotEmpty)
              _SetChips(
                sets: progress.sets,
                selected: setId,
                onSelect: _selectSet,
              ),
            if (selected != null) _CompletionPanel(row: selected),
            _FilterChips(owned: owned, onChanged: _setFilter),
            Expanded(
              child: _BinderBody(
                setId: setId,
                owned: owned,
                pages: pages,
                controller: _controller,
                progressError: progressAsync.hasError,
                onRetryProgress: () =>
                    ref.invalidate(collectionProgressProvider),
                onPageChanged: (index) => setState(() => _current = index),
              ),
            ),
            if (setId != null && total > 0)
              _PageIndicator(current: _current, pages: pages),
          ],
        ),
      ),
    );
  }
}

/// Message affichable d'une erreur de provider (mêmes règles que l'onglet).
String _messageOf(Object? error) => error is ApiException
    ? error.message
    : 'Chargement impossible. Réessaie plus tard.';

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 18, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Retour',
            icon: const Icon(Icons.arrow_back),
          ),
          Text('Classeur', style: text.displaySmall.copyWith(fontSize: 20)),
        ],
      ),
    );
  }
}

/// Une puce par set : identifiant, pourcentage, coche quand il est complet.
class _SetChips extends StatelessWidget {
  const _SetChips({
    required this.sets,
    required this.selected,
    required this.onSelect,
  });

  final List<SetCompletion> sets;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        scrollDirection: Axis.horizontal,
        itemCount: sets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final row = sets[index];
          final done = row.missing == 0;
          return ChoiceChip(
            avatar: done ? const Icon(Icons.check, size: 15) : null,
            label: Text(
              done
                  ? row.setId.toUpperCase()
                  : '${row.setId.toUpperCase()} · ${row.percent} %',
            ),
            tooltip: row.name,
            selected: row.setId == selected,
            onSelected: (_) => onSelect(row.setId),
          );
        },
      ),
    );
  }
}

/// Le set ouvert : nom, compteur, barre prismatique et cartes manquantes.
class _CompletionPanel extends StatelessWidget {
  const _CompletionPanel({required this.row});

  final SetCompletion row;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final missing = row.missingLabel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Reveal(
        child: RiftPanel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.displaySmall.copyWith(fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 8),
                  MonoBadge(label: '${row.owned}/${row.total}'),
                ],
              ),
              const SizedBox(height: 8),
              PrismBar(value: row.ratio, height: 8),
              const SizedBox(height: 5),
              Text(
                '${row.percent} % · '
                '${missing[0].toUpperCase()}${missing.substring(1)}',
                style: text.mono.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tout · Possédées · Manquantes, comme les puces de tri de la collection.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.owned, required this.onChanged});

  final String? owned;
  final ValueChanged<String?> onChanged;

  static const _filters = <(String?, String)>[
    (null, 'Tout'),
    ('1', 'Possédées'),
    ('0', 'Manquantes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Wrap(
        spacing: 8,
        children: [
          for (final (value, label) in _filters)
            FilterChip(
              label: Text(label),
              selected: owned == value,
              onSelected: (_) => onChanged(value),
            ),
        ],
      ),
    );
  }
}

/// Corps du classeur : états d'attente, d'erreur ou de vide, sinon le
/// [PageView] des doubles pages, avec le pivotement de feuille au glissement.
class _BinderBody extends ConsumerWidget {
  const _BinderBody({
    required this.setId,
    required this.owned,
    required this.pages,
    required this.controller,
    required this.progressError,
    required this.onRetryProgress,
    required this.onPageChanged,
  });

  final String? setId;
  final String? owned;
  final int pages;
  final PageController controller;
  final bool progressError;
  final VoidCallback onRetryProgress;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final set = setId;
    if (set == null) {
      return progressError
          ? ErrorView(
              message: 'La progression de ta collection est indisponible.',
              onRetry: onRetryProgress,
            )
          : const LoadingView();
    }

    final request = (setId: set, owned: owned, page: 1);
    final firstPage = ref.watch(binderPageProvider(request));
    return firstPage.when(
      loading: () => const _PageSkeleton(),
      error: (error, _) => ErrorView(
        message: _messageOf(error),
        onRetry: () => ref.invalidate(binderPageProvider(request)),
      ),
      data: (page) {
        if (page.total == 0) return _EmptyBinder(owned: owned);
        return PageView.builder(
          controller: controller,
          itemCount: pages,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) => _PageTurn(
            controller: controller,
            index: index,
            child: _BinderPage(
              request: (setId: set, owned: owned, page: index + 1),
              pages: pages,
            ),
          ),
        );
      },
    );
  }
}

/// Pivotement de feuille pendant le glissement : la page tourne autour du
/// bord relié (gauche), avec un peu de perspective. Coupé quand le système
/// réduit les animations.
class _PageTurn extends StatelessWidget {
  const _PageTurn({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, turned) {
        double delta = 0;
        if (controller.hasClients && controller.position.hasContentDimensions) {
          delta = (controller.page ?? 0) - index;
        }
        final angle = delta.clamp(-1.0, 1.0) * -0.9;
        if (angle == 0) return turned!;
        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..rotateY(angle),
          child: turned,
        );
      },
    );
  }
}

/// Une page : 9 pochettes 3 × 3, dimensionnées pour tenir dans la hauteur
/// disponible. Les pages voisines sont observées pour être déjà chargées
/// quand le doigt arrive.
class _BinderPage extends ConsumerWidget {
  const _BinderPage({required this.request, required this.pages});

  final BinderPageRequest request;
  final int pages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Garder les voisines en vie : le glissement tombe sur une page prête.
    if (request.page > 1) {
      ref.watch(
        binderPageProvider((
          setId: request.setId,
          owned: request.owned,
          page: request.page - 1,
        )),
      );
    }
    if (request.page < pages) {
      ref.watch(
        binderPageProvider((
          setId: request.setId,
          owned: request.owned,
          page: request.page + 1,
        )),
      );
    }

    final page = ref.watch(binderPageProvider(request));
    return page.when(
      loading: () => const _PageSkeleton(),
      error: (error, _) => ErrorView(
        message: _messageOf(error),
        onRetry: () => ref.invalidate(binderPageProvider(request)),
      ),
      data: (data) {
        final cards = List<RiftCard?>.from(data.items);
        while (cards.length < binderPageSize) {
          cards.add(null);
        }
        return _PocketGrid(
          cells: [
            for (final (index, card) in cards.indexed)
              _Pocket(card: card, index: index),
          ],
        );
      },
    );
  }
}

/// Grille 3 × 3 centrée : la taille des pochettes suit la largeur, bornée par
/// la hauteur disponible (paysage, petits écrans).
class _PocketGrid extends StatelessWidget {
  const _PocketGrid({required this.cells});

  final List<Widget> cells;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth - RiftSpace.page.horizontal;
        final maxHeight = constraints.maxHeight - 16;
        final width = math.min(
          (maxWidth - _gap * 2) / 3,
          (maxHeight - _gap * 2) / 3 * CardImage.portraitRatio,
        );
        final height = width / CardImage.portraitRatio;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var row = 0; row < 3; row++)
                Padding(
                  padding: EdgeInsets.only(top: row == 0 ? 0 : _gap),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var column = 0; column < 3; column++)
                        Padding(
                          padding: EdgeInsets.only(
                            left: column == 0 ? 0 : _gap,
                          ),
                          child: SizedBox(
                            width: width,
                            height: height,
                            child: cells[row * 3 + column],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Page en cours de chargement : neuf pochettes vides qui scintillent.
class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) {
    return _PocketGrid(
      cells: [for (var i = 0; i < binderPageSize; i++) const _Pocket(index: 0)],
    );
  }
}

/// Saturation à zéro : le visuel d'une carte manquante vire au gris.
const _grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Une pochette : la carte possédée brille, la manquante est un fantôme gris
/// avec son code et son prix. L'appui ouvre la fiche. Sans carte, la pochette
/// reste une gaine vide.
class _Pocket extends StatelessWidget {
  const _Pocket({this.card, required this.index});

  final RiftCard? card;
  final int index;

  @override
  Widget build(BuildContext context) {
    final sleeve = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: RiftColors.night.withValues(alpha: 0.16),
      border: Border.all(color: RiftColors.goldSoft.withValues(alpha: 0.22)),
    );
    final held = card;
    if (held == null) {
      return Container(decoration: sleeve);
    }

    final text = riftText(context);
    final owned = held.isOwned;
    final shine = !MediaQuery.disableAnimationsOf(context);

    Widget visual = CardImage(
      card: held,
      foil: owned && shine,
      foilIntensity: held.foil ? 1 : 0.55,
      borderRadius: 10,
    );
    // Champ de bataille (paysage) : glissé de côté dans la pochette.
    if (held.isLandscape) {
      visual = RotatedBox(quarterTurns: 1, child: visual);
    }
    if (!owned) {
      visual = Opacity(
        opacity: 0.5,
        child: ColorFiltered(colorFilter: _grayscale, child: visual),
      );
    }

    final price = formatEur(held.priceEur);
    return Reveal(
      index: index,
      child: Semantics(
        button: true,
        label: owned
            ? '${held.name}, ${held.ownedQty} exemplaire(s)'
            : 'Carte manquante : ${held.name}',
        child: PressScale(
          onTap: () => context.go(AppRoutes.card(held.id)),
          child: Container(
            decoration: sleeve,
            padding: const EdgeInsets.all(3),
            child: Stack(
              fit: StackFit.expand,
              children: [
                visual,
                if (owned)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: MonoBadge(label: '×${held.ownedQty}', filled: true),
                  )
                else ...[
                  if (price != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: MonoBadge(
                        label: price,
                        filled: true,
                        color: RiftColors.goldDeep,
                      ),
                    ),
                  Positioned(
                    bottom: 4,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: RiftColors.night.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          held.displayCode,
                          style: text.mono.copyWith(
                            fontSize: 9.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Classeur sans pochette à montrer : toujours une invitation.
class _EmptyBinder extends StatelessWidget {
  const _EmptyBinder({required this.owned});

  final String? owned;

  @override
  Widget build(BuildContext context) {
    if (owned == '0') {
      return const EmptyView(
        title: 'Rien ne manque ici',
        detail: 'Ce set est complet — ton classeur est plein.',
        icon: Icons.verified_outlined,
      );
    }
    if (owned == '1') {
      return EmptyView(
        title: 'Aucune carte possédée dans ce set',
        detail: 'Scanne tes cartes ou note-les depuis leur fiche.',
        icon: Icons.style_outlined,
        action: GoldButton(
          label: 'Scanner une carte',
          icon: Icons.center_focus_strong_outlined,
          expand: false,
          onPressed: () => context.push(AppRoutes.scan),
        ),
      );
    }
    return const EmptyView(
      title: 'Ce set est vide',
      detail: 'Aucune carte connue pour ce set.',
      icon: Icons.auto_stories_outlined,
    );
  }
}

/// « page 3 / 40 » et le geste à connaître.
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.current, required this.pages});

  final int current;
  final int pages;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swipe_outlined, size: 15, color: text.muted),
          const SizedBox(width: 8),
          Text('page ${current + 1} / $pages', style: text.mono),
        ],
      ),
    );
  }
}
