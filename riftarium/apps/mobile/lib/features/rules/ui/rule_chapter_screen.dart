import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/theme.dart';
import '../domain/rules.dart';
import 'rule_section_screen.dart';
import 'rules_navigation.dart';

/// Sommaire d'un chapitre : ses sections.
class RuleChapterScreen extends StatelessWidget {
  const RuleChapterScreen({
    super.key,
    required this.book,
    required this.chapter,
  });

  final RuleBook book;
  final RuleChapter chapter;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return AdaptiveScaffold(
      title: chapter.title,
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        itemCount: chapter.sections.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final section = chapter.sections[index];
          return Reveal(
            index: index,
            child: RiftPanel(
              onTap: () => pushAdaptiveScreen(
                context,
                (_) => RuleSectionScreen(
                  book: book,
                  chapter: chapter,
                  section: section,
                ),
              ),
              child: Row(
                children: [
                  MonoBadge(label: section.bareNumber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: text.displaySmall.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${section.entries.length} '
                          'règle${section.entries.length > 1 ? 's' : ''}',
                          style: text.small,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
