import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cards/data/cards_api.dart';
import '../../cards/domain/card.dart';

/// Une page du classeur : 9 pochettes (3 × 3), soit une page d'API.
const binderPageSize = 9;

/// Requête d'une page du classeur. Un record : l'égalité structurelle sert de
/// clé de cache à la famille de providers.
typedef BinderPageRequest = ({String setId, String? owned, int page});

/// Set ouvert dans le classeur ; null tant que la progression n'a pas parlé
/// (le premier set incomplet est alors choisi).
final binderSetProvider = StateProvider<String?>((ref) => null);

/// Filtre des pochettes : null = tout, '1' = possédées, '0' = manquantes.
final binderOwnedProvider = StateProvider<String?>((ref) => null);

/// Une page de cartes du set, dans l'ordre des numéros collector, avec la
/// quantité possédée. `autoDispose` : chaque page vit tant qu'elle est à
/// l'écran (la page courante garde aussi ses voisines en vie pour que le
/// glissement tombe sur une page déjà chargée), puis repart fraîche — les
/// quantités suivent donc les ajouts faits ailleurs dans l'app.
final binderPageProvider = FutureProvider.autoDispose
    .family<CardPage, BinderPageRequest>((ref, request) {
      final api = ref.watch(cardsApiProvider);
      return api.list(
        filters: CardFilters(setId: request.setId, owned: request.owned),
        page: request.page,
        size: binderPageSize,
      );
    });
