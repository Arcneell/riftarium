import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../auth/application/auth_controller.dart';

/// Ajout d'un exemplaire à la collection depuis le scanner.
///
/// Volontairement autonome (un seul appel, aucun état partagé) : le scanner ne
/// dépend pas de `features/collection`, qui charge des pages entières et
/// n'aurait rien à faire dans la boucle caméra.
///
/// `POST /api/collection/{card_id}/entries` additionne la quantité au lot de
/// même état et même langue — c'est la sémantique « +1 » du scan web
/// (`apps/web/src/views/ScanView.vue`), et non un remplacement comme le PUT.
class ScanCollectionApi {
  ScanCollectionApi(this._dio);

  final Dio _dio;

  /// État par défaut des lots créés par le scanner (valeurs par défaut de
  /// `CollectionEntryIn`, côté API).
  static const String condition = 'NM';
  static const String lang = 'EN';

  /// Ajoute [qty] exemplaire(s) et renvoie la quantité totale possédée après
  /// l'ajout (`total_qty` de la réponse).
  Future<int> addOne(String cardId, {int qty = 1}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/collection/$cardId/entries',
        data: {'qty': qty, 'condition': condition, 'lang': lang},
      );
      return (response.data?['total_qty'] as num?)?.toInt() ?? qty;
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }
}

final scanCollectionApiProvider = Provider<ScanCollectionApi>(
  (ref) => ScanCollectionApi(ref.watch(dioProvider)),
);
