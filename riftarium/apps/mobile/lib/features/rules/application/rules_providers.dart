import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/rules_repository.dart';
import '../domain/rules.dart';

/// Accès aux règles (asset + cache + réseau). Remplacé dans les tests.
final rulesRepositoryProvider = Provider<RulesRepository>(
  (ref) => RulesRepository(),
);

/// Issue d'un rafraîchissement manuel, avec le message affiché à l'écran.
enum RulesRefreshOutcome {
  updated('Règles mises à jour depuis riftarium.re.'),
  upToDate('Les règles sont déjà à jour.'),
  failed(
    'Mise à jour impossible. '
    'Les règles enregistrées restent consultables hors ligne.',
  );

  const RulesRefreshOutcome(this.message);

  final String message;
}

/// Document des règles : version locale immédiate, mise à jour en ligne
/// appliquée dès qu'elle arrive (jamais bloquante).
final rulesProvider = AsyncNotifierProvider<RulesController, RulesDocument>(
  RulesController.new,
);

class RulesController extends AsyncNotifier<RulesDocument> {
  bool _disposed = false;

  @override
  Future<RulesDocument> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final document = await ref.watch(rulesRepositoryProvider).load();
    // Vérification en arrière-plan : l'écran s'affiche sans attendre le réseau.
    unawaited(_checkForUpdate(document));
    return document;
  }

  Future<void> _checkForUpdate(RulesDocument current) async {
    try {
      final fresh = await ref
          .read(rulesRepositoryProvider)
          .fetchUpdate(current);
      if (fresh != null && !_disposed) state = AsyncData(fresh);
    } on Object {
      // Hors ligne ou site injoignable : la version locale suffit.
      return;
    }
  }

  /// Bouton « Actualiser » : va chercher la version en ligne maintenant.
  Future<RulesRefreshOutcome> refresh() async {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return RulesRefreshOutcome.updated;
    }
    try {
      final fresh = await ref
          .read(rulesRepositoryProvider)
          .fetchUpdate(current);
      if (fresh == null) return RulesRefreshOutcome.upToDate;
      if (!_disposed) state = AsyncData(fresh);
      return RulesRefreshOutcome.updated;
    } on Object {
      return RulesRefreshOutcome.failed;
    }
  }
}

/// Recherche globale (les deux livres) pour la requête donnée. `autoDispose` :
/// chaque frappe crée une entrée, aucune ne doit survivre à l'écran.
final ruleSearchProvider = Provider.autoDispose
    .family<List<RuleSearchHit>, String>((ref, query) {
      final document = ref.watch(rulesProvider).valueOrNull;
      if (document == null) return const [];
      return searchRules(document, query);
    });
