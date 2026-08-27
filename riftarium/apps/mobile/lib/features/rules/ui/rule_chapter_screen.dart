import 'package:flutter/material.dart';

import '../../../app/adaptive.dart';
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
    final theme = Theme.of(context);
    return AdaptiveScaffold(
      title: chapter.title,
      // `ListTile` a besoin d'un ancêtre Material, absent du scaffold iOS.
      body: Material(
        type: MaterialType.transparency,
        child: ListView.separated(
          itemCount: chapter.sections.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final section = chapter.sections[index];
            return ListTile(
              title: Text('${section.bareNumber} · ${section.title}'),
              subtitle: Text(
                '${section.entries.length} règles',
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => pushAdaptiveScreen(
                context,
                (_) => RuleSectionScreen(
                  book: book,
                  chapter: chapter,
                  section: section,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
