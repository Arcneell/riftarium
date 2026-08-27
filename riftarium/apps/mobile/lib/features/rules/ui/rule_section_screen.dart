import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../application/rules_providers.dart';
import '../domain/rules.dart';
import 'rule_entry_view.dart';
import 'rules_navigation.dart';

/// Ouvre la section d'une position (recherche, renvoi) en mettant la règle
/// visée en évidence.
void openRuleLocation(BuildContext context, RuleLocation location) {
  pushAdaptiveScreen(
    context,
    (_) => RuleSectionScreen(
      book: location.book,
      chapter: location.chapter,
      section: location.section,
      highlightEntryId: location.entry?.id,
    ),
  );
}

/// Texte d'une section : toutes ses règles, dans l'ordre.
class RuleSectionScreen extends ConsumerStatefulWidget {
  const RuleSectionScreen({
    super.key,
    required this.book,
    required this.chapter,
    required this.section,
    this.highlightEntryId,
  });

  final RuleBook book;
  final RuleChapter chapter;
  final RuleSection section;

  /// Identifiant de la règle à mettre en évidence (recherche ou renvoi).
  final String? highlightEntryId;

  @override
  ConsumerState<RuleSectionScreen> createState() => _RuleSectionScreenState();
}

class _RuleSectionScreenState extends ConsumerState<RuleSectionScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.highlightEntryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealHighlight());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// La liste est paresseuse : la règle visée n'est pas encore construite si
  /// elle est loin. On avance d'un écran à la fois jusqu'à ce qu'elle existe.
  Future<void> _revealHighlight() async {
    for (var attempt = 0; attempt < 12; attempt++) {
      if (!mounted) return;
      final target = _highlightKey.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.15,
          duration: Duration.zero,
        );
        return;
      }
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent) return;
      _scrollController.jumpTo(
        math.min(
          position.pixels + position.viewportDimension * 0.8,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  void _followReference(RuleReference reference) {
    final document = ref.read(rulesProvider).valueOrNull;
    final location = document?.locate(
      reference.number,
      fromBookKey: widget.book.key,
    );
    if (location == null) {
      showAdaptiveMessage(
        context,
        title: 'Renvoi introuvable',
        message: 'La règle ${reference.number} n’est pas dans ce document.',
      );
      return;
    }
    openRuleLocation(context, location);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final section = widget.section;
    return AdaptiveScaffold(
      title: section.title,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.book.title} › ${widget.chapter.title}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(section.title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Section ${section.bareNumber} · '
                    '${section.entries.length} règles · '
                    'mise à jour du ${widget.book.updated}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: section.entries.length,
            itemBuilder: (context, index) {
              final entry = section.entries[index];
              final highlighted = entry.id == widget.highlightEntryId;
              return RuleEntryView(
                key: highlighted ? _highlightKey : null,
                entry: entry,
                highlighted: highlighted,
                onFollowReference: _followReference,
              );
            },
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Text(
                'Texte reproduit depuis « ${widget.book.title} » '
                '(mise à jour du ${widget.book.updated}), publié par Riot '
                'Games. En cas de divergence, le PDF officiel fait foi.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
