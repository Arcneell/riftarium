import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/cards/data/cards_api.dart';
import 'package:riftarium_mobile/features/cards/domain/card.dart';
import 'package:riftarium_mobile/features/game/data/legends_repository.dart';

import '../../support/fakes.dart';

/// Trois cartes : deux variantes d'une même légende, plus une autre légende.
const _page = {
  'total': 3,
  'page': 1,
  'size': 100,
  'items': [
    {
      'id': 'OGN-101a',
      'riftbound_id': 'RB-JINX',
      'name': 'Jinx',
      'set_id': 'OGN',
      'type': 'Legend',
      'rarity': 'Épique',
      'domains': ['Chaos'],
      'collector_number': 101,
      'alternate_art': true,
    },
    {
      'id': 'OGN-101',
      'riftbound_id': 'RB-JINX',
      'name': 'Jinx',
      'set_id': 'OGN',
      'type': 'Legend',
      'rarity': 'Épique',
      'domains': ['Chaos'],
      'collector_number': 101,
    },
    _annie,
  ],
};

const _annie = {
  'id': 'OGN-004',
  'riftbound_id': 'RB-ANNIE',
  'name': 'Annie',
  'set_id': 'OGN',
  'type': 'Legend',
  'rarity': 'Rare',
  'domains': ['Fury'],
  'collector_number': 4,
};

/// Cache injectable : mémorise ce qu'on lui écrit, comme le ferait le fichier.
class FakeLegendsCache implements LegendsCacheStore {
  FakeLegendsCache({this.cards, this.fetchedAt});

  List<RiftCard>? cards;
  DateTime? fetchedAt;
  int writes = 0;

  @override
  Future<({List<RiftCard> cards, DateTime fetchedAt})?> read() async {
    final stored = cards;
    if (stored == null) return null;
    return (cards: stored, fetchedAt: fetchedAt ?? DateTime(2020));
  }

  @override
  Future<bool> write(List<RiftCard> cards, DateTime fetchedAt) async {
    this.cards = cards;
    this.fetchedAt = fetchedAt;
    writes++;
    return true;
  }
}

void main() {
  final now = DateTime.utc(2026, 8, 28);

  CardsApi apiWith(FakeHttpAdapter adapter) =>
      CardsApi(Dio()..httpClientAdapter = adapter);

  test('les variantes sont groupées, la version normale en tête', () async {
    final adapter = FakeHttpAdapter({
      'GET /cards': const FakeResponse(200, _page),
    });
    final cache = FakeLegendsCache();
    final groups = await LegendsRepository(
      api: apiWith(adapter),
      cache: cache,
    ).load(now: now);

    expect(groups.map((group) => group.name), ['Annie', 'Jinx']);
    final jinx = groups.last;
    expect(jinx.variants.length, 2);
    expect(legendVariantLabel(jinx.base), isNull);
    expect(legendVariantLabel(jinx.variants[1]), 'Alt-art');
    expect(jinx.domains, ['Chaos']);
    expect(jinx.matches('JINX'), isTrue);
    expect(jinx.matches('ann'), isFalse);

    // Le résultat est mis de côté pour la prochaine ouverture hors ligne.
    expect(cache.writes, 1);
    expect(cache.cards, hasLength(3));
  });

  test('un cache frais répond seul, sans toucher au réseau', () async {
    final adapter = FakeHttpAdapter({});
    final cache = FakeLegendsCache(
      cards: [RiftCard.fromJson(_annie)],
      fetchedAt: now.subtract(const Duration(days: 1)),
    );
    final groups = await LegendsRepository(
      api: apiWith(adapter),
      cache: cache,
    ).load(now: now);

    expect(groups.single.name, 'Annie');
    expect(adapter.requests, isEmpty);
  });

  test('sans réseau, un cache périmé vaut mieux que rien', () async {
    final adapter = FakeHttpAdapter({
      'GET /cards': const FakeResponse.networkError(),
    });
    final cache = FakeLegendsCache(
      cards: [RiftCard.fromJson(_annie)],
      fetchedAt: now.subtract(const Duration(days: 90)),
    );
    final groups = await LegendsRepository(
      api: apiWith(adapter),
      cache: cache,
    ).load(now: now);

    expect(adapter.requests, hasLength(1));
    expect(groups.single.name, 'Annie');
    expect(cache.writes, 0);
  });

  test('sans réseau ni cache, l’erreur remonte au sélecteur', () async {
    final repository = LegendsRepository(
      api: apiWith(
        FakeHttpAdapter({'GET /cards': const FakeResponse.networkError()}),
      ),
      cache: FakeLegendsCache(),
    );
    await expectLater(repository.load(now: now), throwsA(isA<Object>()));
  });
}
