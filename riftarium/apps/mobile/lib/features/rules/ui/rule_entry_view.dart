import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/design/reveal.dart';
import '../../../app/theme.dart';
import '../domain/rules.dart';
import 'rule_rich_text.dart';

/// Rendu d'une règle : numéro doré, indentation selon `depth`, texte enrichi
/// (glyphes et mots-clés comme sur les cartes), exemples en encart et renvois
/// cliquables.
class RuleEntryView extends StatelessWidget {
  const RuleEntryView({
    super.key,
    required this.entry,
    this.highlighted = false,
    this.onFollowReference,
  });

  final RuleEntry entry;

  /// Règle atteinte par une recherche ou un renvoi : fond mis en évidence.
  final bool highlighted;

  final ValueChanged<RuleReference>? onFollowReference;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final indent = math.min(math.max(entry.depth, 0), 4) * 12.0;
    return Container(
      margin: EdgeInsets.fromLTRB(indent, 4, 0, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: highlighted
          ? BoxDecoration(
              color: RiftColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(RiftRadius.sm),
              border: Border.all(
                color: RiftColors.gold.withValues(alpha: 0.55),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${entry.number} ',
                  style: text.mono.copyWith(
                    color: RiftColors.goldDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ...ruleTextSpans(context, entry.text, style: text.body),
              ],
            ),
            style: text.body,
          ),
          for (final example in entry.examples) _ExampleBox(text: example.text),
          if (entry.refs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reference in entry.refs)
                    _ReferenceChip(
                      reference: reference,
                      onTap: onFollowReference == null
                          ? null
                          : () => onFollowReference!(reference),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Encart « Exemple » du document officiel : filet or à gauche.
class _ExampleBox extends StatelessWidget {
  const _ExampleBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final styles = riftText(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        border: const Border(
          left: BorderSide(color: RiftColors.gold, width: 3),
        ),
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(RiftRadius.sm),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Exemple'.toUpperCase(), style: styles.eyebrow),
          const SizedBox(height: 4),
          RuleRichText(text, style: styles.small.copyWith(color: styles.ink)),
        ],
      ),
    );
  }
}

/// Renvoi vers une autre règle.
class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({required this.reference, this.onTap});

  final RuleReference reference;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: RiftColors.hex.withValues(alpha: 0.5)),
          color: RiftColors.hex.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(RiftRadius.full),
        ),
        // Le renvoi tient sur une ligne : dans un `Wrap`, un libellé long
        // pousserait la puce au-delà de la largeur de l'écran.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(
            '→ ${reference.number} ${reference.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.mono.copyWith(color: RiftColors.calmText),
          ),
        ),
      ),
    );
  }
}
