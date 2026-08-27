import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/card_text.dart';
import 'card_glyph.dart';

/// Texte de règles d'une carte, rendu comme sur le site (`CardText.vue`) :
/// mots-clés en pastille colorée selon leur famille, glyphes officiels
/// dessinés dans la ligne, le reste en texte courant.
class CardTextView extends StatelessWidget {
  const CardTextView({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final parts = parseCardText(text);
    if (parts.isEmpty) return const SizedBox.shrink();
    final style = riftText(context).body;

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final part in parts)
            switch (part) {
              CardTextRun(:final value) => TextSpan(text: value),
              final CardTextKeyword keyword => WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: _KeywordPill(keyword: keyword),
              ),
              final CardTextGlyph glyph => WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: CardGlyph(glyph: glyph, size: style.fontSize! * 1.15),
                ),
              ),
            },
        ],
      ),
    );
  }
}

/// Pastille d'un mot-clé : capitales italiques blanches sur la couleur de sa
/// famille. Le chevron (`[Action] [>]`) taille la pastille en pointe.
class _KeywordPill extends StatelessWidget {
  const _KeywordPill({required this.keyword});

  final CardTextKeyword keyword;

  /// Familles du site transposées dans la palette Riftarium : temporalité en
  /// calme, combat en chaos, état en corps, le reste en encre sourde.
  static Color _colorOf(KeywordFamily family) => switch (family) {
    KeywordFamily.timing => RiftColors.calmText,
    KeywordFamily.combat => RiftColors.chaos,
    KeywordFamily.state => RiftColors.body,
    KeywordFamily.utility => RiftColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final pill = Container(
      padding: EdgeInsets.only(
        left: 6,
        right: keyword.arrow ? 12 : 6,
        top: 1,
        bottom: 1,
      ),
      color: _colorOf(keyword.family),
      child: Text(
        keyword.label.toUpperCase(),
        style: text.small.copyWith(
          fontSize: 11.5,
          fontStyle: FontStyle.italic,
          fontVariations: RiftFonts.weight(700),
          letterSpacing: 0.5,
          height: 1.25,
          color: Colors.white,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: keyword.arrow
          ? ClipPath(clipper: const _ArrowClipper(), child: pill)
          : ClipRRect(borderRadius: BorderRadius.circular(3), child: pill),
    );
  }
}

/// Bord droit en pointe, comme `clip-path` sur `.rb-kw.arrow`.
class _ArrowClipper extends CustomClipper<Path> {
  const _ArrowClipper();

  @override
  Path getClip(Size size) {
    const tip = 6.0;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - tip, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - tip, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
