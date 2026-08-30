import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/cards/application/cards_controller.dart';
import 'package:riftarium_mobile/features/cards/data/cards_api.dart';
import 'package:riftarium_mobile/features/cards/domain/card_set.dart';
import 'package:riftarium_mobile/features/cards/domain/prices_meta.dart';

import 'support/cards_fixtures.dart';

void main() {
  group('CardFilters.toQuery', () {
    test('sans critère, aucun paramètre n’est envoyé', () {
      expect(const CardFilters().toQuery(), isEmpty);
      expect(const CardFilters().isEmpty, isTrue);
    });

    test('chaque critère porte le nom attendu par l’API', () {
      const filters = CardFilters(
        query: 'jinx',
        setId: 'OGN',
        type: 'Unit',
        domain: 'Fury',
        rarity: 'Rare',
        energy: '7+',
        owned: '1',
        sort: 'rarity',
      );

      expect(filters.toQuery(), {
        'q': 'jinx',
        'set_id': 'OGN',
        'type': 'Unit',
        'domain': 'Fury',
        'rarity': 'Rare',
        'energy': '7+',
        'owned': '1',
        'sort': 'rarity',
      });
    });

    test('une recherche vide ne devient pas un paramètre q', () {
      expect(const CardFilters(query: '').toQuery(), isEmpty);
    });
  });

  group('CardFiltersController', () {
    late ProviderContainer container;
    late CardFiltersController controller;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      controller = container.read(cardFiltersProvider.notifier);
    });

    test('la recherche est nettoyée de ses espaces', () {
      controller.setQuery('  jinx  ');
      expect(container.read(cardFiltersProvider).query, 'jinx');
    });

    test('passer null à une facette la retire', () {
      controller.setDomain('Fury');
      expect(container.read(cardFiltersProvider).domain, 'Fury');

      controller.setDomain(null);
      expect(container.read(cardFiltersProvider).domain, isNull);
    });

    test('la réinitialisation garde la recherche en cours', () {
      controller.setQuery('jinx');
      controller.setRarity('Epic');
      controller.setOwned('0');
      controller.setSort('random');

      controller.clearFacets();

      final filters = container.read(cardFiltersProvider);
      expect(filters.query, 'jinx');
      expect(filters.rarity, isNull);
      expect(filters.owned, isNull);
      expect(filters.sort, isNull);
    });
  });

  group('Réponses annexes', () {
    test('/sets est une liste nue d’objets set', () {
      final sets = setsJson.map(CardSet.fromJson).toList();

      expect(sets, hasLength(2));
      expect(sets.first.setId, 'OGN');
      expect(sets.first.label, 'Origines');
      expect(sets.first.cardCount, 298);
      expect(sets.first.publishedOn, '2025-10-31');
    });

    test('/prices/meta porte la fraîcheur et l’origine des prix', () {
      final meta = PricesMeta.fromJson(pricesMetaJson);

      expect(meta.source, 'tcgplayer');
      expect(meta.rate, 0.92);
      expect(meta.pricedCards, 512);
      expect(meta.note, contains('TCGplayer'));
      expect(meta.note, contains('20/08/2026'));
    });

    test('sans méta chargée, la note de repli reste complète', () {
      const meta = PricesMeta();

      expect(meta.note, contains('TCGplayer'));
      expect(meta.note, contains('taux BCE'));
    });
  });
}
