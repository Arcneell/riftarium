import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/features/decks/data/decks_api.dart';
import 'package:riftarium_mobile/features/decks/domain/deck.dart';

import 'support/decks_fixtures.dart';

void main() {
  ({DecksApi api, DecksFakeApi server}) build(Map<String, Object> routes) {
    final server = DecksFakeApi(routes);
    return (
      api: DecksApi(
        createApiClient(
          readToken: () async => 'jwt',
          baseUrl: 'https://api.test/api',
          adapter: server,
        ),
      ),
      server: server,
    );
  }

  test('mine lit la liste JSON nue', () async {
    final fake = build({
      'GET /decks/mine': [
        deckJson(id: 1, name: 'Ahri', likes: 4),
        deckJson(id: 2, name: 'Jinx', isPublic: true),
      ],
    });

    final decks = await fake.api.mine();
    expect(decks.map((deck) => deck.name), ['Ahri', 'Jinx']);
    expect(decks.first.likes, 4);
    expect(decks[1].isPublic, isTrue);
  });

  test('get lit les cartes, les contrôles et les prix', () async {
    final fake = build({
      'GET /decks/7': deckJson(
        id: 7,
        totalEur: 42.5,
        cards: [
          deckEntryJson(deckCardJson(id: 'L', name: 'Ahri', type: 'Legend'), 1),
          deckEntryJson(deckCardJson(id: 'U', name: 'Unité'), 3),
        ],
        checks: [
          checkJson('legend', true, 'Exactement 1 légende (1 actuellement)'),
          checkJson('runes', false, '12 runes (0 actuellement)'),
        ],
      ),
    });

    final deck = await fake.api.get(7);
    expect(deck.cardCount, 4);
    expect(deck.legend?.name, 'Ahri');
    expect(deck.isLegal, isFalse);
    expect(deck.checks.last.message, '12 runes (0 actuellement)');
    expect(deck.totalEur, 42.5);
  });

  test('create envoie le corps attendu par DeckIn', () async {
    final fake = build({'POST /decks': deckJson(id: 3, name: 'Nouveau')});

    final deck = await fake.api.create(
      const DeckInput(
        name: 'Nouveau',
        description: 'Plan de jeu',
        format: 'free',
        isPublic: true,
        cards: [DeckCardInput('OGN-001', 3)],
      ),
    );

    expect(deck.id, 3);
    final body = fake.server.on('POST', '/decks').single.data! as Map;
    expect(body['name'], 'Nouveau');
    expect(body['description'], 'Plan de jeu');
    expect(body['format'], 'free');
    expect(body['is_public'], isTrue);
    expect(body['cards'], [
      {'card_id': 'OGN-001', 'qty': 3},
    ]);
  });

  test('update passe par PUT sur le deck', () async {
    final fake = build({'PUT /decks/9': deckJson(id: 9, name: 'Modifié')});

    final deck = await fake.api.update(9, const DeckInput(name: 'Modifié'));
    expect(deck.name, 'Modifié');
    expect(fake.server.calls, ['PUT /decks/9']);
  });

  test('delete et copy appellent les bons chemins', () async {
    final fake = build({
      'DELETE /decks/4': <String, dynamic>{},
      'POST /decks/4/copy': deckJson(id: 5, name: 'Ahri (copie)'),
    });

    await fake.api.delete(4);
    final copy = await fake.api.copy(4);
    expect(copy.name, 'Ahri (copie)');
    expect(fake.server.calls, ['DELETE /decks/4', 'POST /decks/4/copy']);
  });

  test('toggleLike et recordView lisent la réponse', () async {
    final fake = build({
      'POST /decks/2/like': {'deck_id': 2, 'likes': 8, 'liked_by_me': true},
      'POST /decks/2/view': {'deck_id': 2, 'views': 31, 'counted': true},
    });

    final like = await fake.api.toggleLike(2);
    expect(like.likes, 8);
    expect(like.likedByMe, isTrue);
    expect(await fake.api.recordView(2), 31);
  });

  test('missing rend la liste d’achats', () async {
    final fake = build({
      'GET /decks/2/missing': {
        'items': [
          {
            'card': deckCardJson(id: 'U', name: 'Unité'),
            'needed': 3,
            'owned': 1,
            'missing': 2,
          },
        ],
        'missing_total': 2,
        'deck_total': 40,
      },
    });

    final missing = await fake.api.missing(2);
    expect(missing.missingTotal, 2);
    expect(missing.deckTotal, 40);
    expect(missing.items.single.card.name, 'Unité');
    expect(missing.items.single.missing, 2);
  });

  test('communityLegends lit la liste JSON nue', () async {
    final fake = build({
      'GET /community/legends': [
        {'id': 'OGN-247', 'name': 'Ahri', 'image_url': null, 'deck_count': 12},
      ],
    });

    final legends = await fake.api.communityLegends();
    expect(legends.single.name, 'Ahri');
    expect(legends.single.deckCount, 12);
  });

  test('communityDecks sérialise les filtres en paramètres', () async {
    final fake = build({
      'GET /community/decks': communityPageJson(
        total: 42,
        page: 2,
        items: [
          communityDeckJson(
            id: 1,
            legend: deckCardJson(id: 'L', name: 'Ahri', type: 'Legend'),
            missingCards: 3,
            missingCostEur: 4.5,
          ),
        ],
      ),
    });

    final page = await fake.api.communityDecks(
      filters: const CommunityFilters(
        query: 'ahri',
        legends: ['OGN-247', 'OGN-248'],
        domains: ['Fury'],
        formats: ['tournament'],
        sort: 'recent',
        liked: true,
        buildable: true,
      ),
      page: 2,
    );

    expect(page.total, 42);
    expect(page.pageCount, 3);
    expect(page.items.single.legend?.name, 'Ahri');
    expect(page.items.single.missingCards, 3);

    final query = fake.server.on('GET', '/community/decks').single;
    expect(query.queryParameters, {
      'q': 'ahri',
      'legend': 'OGN-247,OGN-248',
      'domain': 'Fury',
      'format': 'tournament',
      'sort': 'recent',
      'liked': '1',
      'buildable': '1',
      'page': 2,
      'size': 20,
    });
  });

  test('les filtres vides n’envoient que le tri et la pagination', () async {
    final fake = build({
      'GET /community/decks': communityPageJson(items: const []),
    });

    await fake.api.communityDecks();
    expect(fake.server.on('GET', '/community/decks').single.queryParameters, {
      'sort': 'likes',
      'page': 1,
      'size': 20,
    });
  });

  test('une erreur de l’API devient une ApiException lisible', () async {
    final fake = build({
      'GET /decks/99': const DecksFakeError(404, 'Deck introuvable'),
    });

    await expectLater(
      fake.api.get(99),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Deck introuvable')
            .having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });

  test('activeCount compte les filtres actifs, pas le tri', () {
    expect(const CommunityFilters().activeCount, 0);
    expect(const CommunityFilters(sort: 'recent').activeCount, 0);
    expect(const CommunityFilters(query: 'ahri', liked: true).activeCount, 2);
  });
}
