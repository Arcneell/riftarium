import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../application/guides_providers.dart';
import '../application/rules_providers.dart';
import '../domain/guides.dart';
import 'rule_rich_text.dart';
import 'rule_section_screen.dart';
import 'rules_navigation.dart';
import 'widgets/guide_board.dart';

/// Guide du débutant : le jeu montré étape par étape sur un plateau.
///
/// Une étape = une scène (les cartes officielles posées à leur place) et
/// quelques phrases. On avance au doigt ou avec les boutons ; chaque étape
/// renvoie à la règle officielle correspondante.
class BeginnerGuideScreen extends ConsumerStatefulWidget {
  const BeginnerGuideScreen({super.key});

  @override
  ConsumerState<BeginnerGuideScreen> createState() =>
      _BeginnerGuideScreenState();
}

class _BeginnerGuideScreenState extends ConsumerState<BeginnerGuideScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index, int total) {
    if (index < 0 || index >= total) return;
    _controller.animateToPage(
      index,
      duration: RiftMotion.base,
      curve: RiftMotion.ease,
    );
  }

  /// Ouvre la section officielle d'une étape (« Règle 315 »).
  void _openReference(String reference) {
    final document = ref.read(rulesProvider).valueOrNull;
    final location = document?.locate(reference, fromBookKey: 'core');
    if (location == null) {
      context.go(AppRoutes.officialRules);
      return;
    }
    openRuleLocation(context, location);
  }

  @override
  Widget build(BuildContext context) {
    final guides = ref.watch(guidesProvider);
    return Scaffold(
      body: SafeArea(
        child: guides.when(
          loading: () => const LoadingView(),
          error: (error, stack) => ErrorView(
            message: 'Impossible de charger le guide du débutant.',
            onRetry: () => ref.invalidate(guidesProvider),
          ),
          data: (document) => document.steps.isEmpty
              ? const EmptyView(
                  title: 'Guide indisponible',
                  detail: 'Le pas à pas n’a pas pu être lu.',
                )
              : _body(document),
        ),
      ),
    );
  }

  Widget _body(GuidesDocument document) {
    final steps = document.steps;
    final total = steps.length;
    final index = _index.clamp(0, total - 1);
    final text = riftText(context);

    return Column(
      children: [
        _Header(
          index: index,
          total: total,
          title: steps[index].title,
          onSelect: (value) => _goTo(value, total),
        ),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: total,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, page) => _StepView(
              step: steps[page],
              document: document,
              onOpenReference: _openReference,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Précédent',
                  icon: Icons.arrow_back,
                  onPressed: index == 0 ? null : () => _goTo(index - 1, total),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: index == total - 1
                    ? GoldButton(
                        label: 'Terminer',
                        icon: Icons.bolt_outlined,
                        onPressed: () => context.go(AppRoutes.advancedHelp),
                      )
                    : GoldButton(
                        label: 'Suivant',
                        onPressed: () => _goTo(index + 1, total),
                      ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Cartes et visuels officiels Riftbound — © Riot Games.',
            style: text.mono.copyWith(fontSize: 10),
          ),
        ),
      ],
    );
  }
}

/// Barre du haut : retour, compteur d'étape, points de progression.
class _Header extends StatelessWidget {
  const _Header({
    required this.index,
    required this.total,
    required this.title,
    required this.onSelect,
  });

  final int index;
  final int total;
  final String title;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RulesBackButton(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Guide du débutant'.toUpperCase(),
                      style: text.eyebrow,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Étape ${index + 1} sur $total',
                      style: text.monoStrong,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Semantics(
              label: 'Étape ${index + 1} sur $total : $title',
              child: Row(
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 1.5,
                            vertical: 6,
                          ),
                          child: AnimatedContainer(
                            duration: RiftMotion.quick,
                            height: i == index ? 5 : 3,
                            decoration: BoxDecoration(
                              color: i <= index
                                  ? RiftColors.gold
                                  : RiftColors.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                RiftRadius.full,
                              ),
                            ),
                          ),
                        ),
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

/// Une étape : le plateau, le titre, les termes introduits, le texte et le
/// renvoi vers la règle officielle.
class _StepView extends StatelessWidget {
  const _StepView({
    required this.step,
    required this.document,
    required this.onOpenReference,
  });

  final GuideStep step;
  final GuidesDocument document;
  final ValueChanged<String> onOpenReference;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      children: [
        GuideBoard(
          scene: step.scene,
          boardCards: document.boardCards,
          spots: document.spots,
        ),
        const SizedBox(height: 18),
        Text(step.title, style: text.displayMedium),
        if (step.terms.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final term in step.terms) MonoBadge(label: term)],
          ),
        ],
        const SizedBox(height: 14),
        for (final paragraph in step.text) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 10),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: RiftColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(child: RuleRichText(paragraph)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (step.reference.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: PressScale(
              onTap: () => onOpenReference(step.reference),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Règle ${step.reference} ↗',
                  style: text.bodyStrong.copyWith(
                    fontSize: 14,
                    color: RiftColors.calmText,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
