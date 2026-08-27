import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/guides_repository.dart';
import '../domain/guides.dart';

/// Accès aux guides embarqués. Remplacé dans les tests.
final guidesRepositoryProvider = Provider<GuidesRepository>(
  (ref) => const GuidesRepository(),
);

/// Guides décodés. Gardés en mémoire : le hub, le guide du débutant et
/// chaque sujet lisent le même document.
final guidesProvider = FutureProvider<GuidesDocument>(
  (ref) => ref.watch(guidesRepositoryProvider).load(),
);

/// Un sujet de l'aide avancée, ou null s'il n'existe pas.
final guideTopicProvider = Provider.autoDispose.family<GuideTopic?, String>((
  ref,
  slug,
) {
  final document = ref.watch(guidesProvider).valueOrNull;
  return document?.topicBySlug(slug);
});

/// Recherche dans les sujets. `autoDispose` : une entrée par frappe.
final guideSearchProvider = Provider.autoDispose
    .family<List<GuideTopic>, String>((ref, query) {
      final document = ref.watch(guidesProvider).valueOrNull;
      if (document == null) return const [];
      return searchGuideTopics(document, query);
    });
