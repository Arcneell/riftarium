import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../cards/domain/card.dart';
import '../domain/collector_code.dart';

/// Index du scan : `GET /api/cards/hashes`.
///
/// L'endpoint renvoie `{algo, count, items: [{id, rid, h}]}` — une ligne par
/// carte, `h` (l'empreinte perceptuelle) valant null tant qu'elle n'a pas été
/// calculée. Le mobile n'utilise que `id` et `rid` : l'identification se fait
/// uniquement par le code imprimé, l'empreinte n'est pas portée.
///
/// `?v=2` reproduit ce que demande le web : la clé de cache serveur est
/// versionnée et l'ancien format ne contenait pas `rid`.
class ScanIndexApi {
  ScanIndexApi(this._dio);

  final Dio _dio;

  Future<ScanIndex> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/cards/hashes',
        queryParameters: const {'v': 2},
      );
      final items = response.data?['items'] as List? ?? const [];
      final entries = <ScanIndexEntry>[];
      for (final item in items.whereType<Map>()) {
        final id = item['id'];
        final rid = item['rid'];
        if (id is! String || rid is! String || rid.isEmpty) continue;
        entries.add(ScanIndexEntry(id: id, rid: rid));
      }
      return ScanIndex(entries);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }
}

/// Index chargé en mémoire, prêt à résoudre un code lu en identifiant de carte.
class ScanIndex {
  ScanIndex(List<ScanIndexEntry> entries)
    : entries = List.unmodifiable(entries),
      totals = collectorTotals(entries);

  final List<ScanIndexEntry> entries;

  /// Totaux d'impression connus : sans eux, aucune lecture n'est acceptée.
  final Set<int> totals;

  /// Faux quand l'index est vide ou dépourvu de `riftbound_id` exploitable :
  /// le scanner ne peut alors rien reconnaître.
  bool get isUsable => totals.isNotEmpty;

  /// Lit un code dans les lignes de texte reconnues (du bas de l'image vers le
  /// haut : le code est imprimé en pied de carte).
  CollectorCode? read(List<String> lines) =>
      parseCollectorCodeFromLines(lines, totals);

  /// Meilleure carte pour un code lu, ou null si le code n'existe pas ici.
  ScanIndexEntry? resolve(CollectorCode code) {
    final matches = matchByCode(code, entries);
    return matches.isEmpty ? null : matches.first;
  }
}

final scanIndexApiProvider = Provider<ScanIndexApi>(
  (ref) => ScanIndexApi(ref.watch(dioProvider)),
);

/// Index gardé en mémoire pour toute la session : quelques centaines de
/// kilo-octets, rechargés seulement si l'appel a échoué (`ref.invalidate`).
final scanIndexProvider = FutureProvider<ScanIndex>(
  (ref) => ref.watch(scanIndexApiProvider).fetch(),
);

/// Vérifie qu'une carte chargée correspond bien au code lu (`set_id` +
/// `collector_number`), en dernier contrôle avant de l'afficher.
bool cardMatchesCode(RiftCard card, CollectorCode code) {
  if (card.collectorNumber != code.number) return false;
  return code.set == null || card.setId.toUpperCase() == code.set;
}
