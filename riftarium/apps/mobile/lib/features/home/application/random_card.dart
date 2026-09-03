import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cards/data/cards_api.dart';
import '../../cards/domain/card.dart';

/// Une carte au hasard à chaque ouverture : le geste du site (« la cartothèque
/// complète ») ramené à un seul visuel qui brille.
final randomCardProvider = FutureProvider.autoDispose<RiftCard?>((ref) async {
  final page = await ref
      .read(cardsApiProvider)
      .list(filters: const CardFilters(sort: 'random'), size: 1);
  return page.items.isEmpty ? null : page.items.first;
});
