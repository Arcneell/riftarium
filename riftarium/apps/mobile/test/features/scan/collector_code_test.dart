import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/scan/domain/collector_code.dart';

void main() {
  // Deux extensions, comme en production : les totaux d'impression sont la
  // seule chose qui distingue une lecture crédible d'un nombre inventé.
  const totals = {219, 298};

  const index = [
    ScanIndexEntry(id: 'OGN-209', rid: 'ogn-209-298'),
    ScanIndexEntry(id: 'OGN-209s', rid: 'ogn-209*-298'),
    ScanIndexEntry(id: 'UNL-229', rid: 'unl-229-219'),
    ScanIndexEntry(id: 'PROMO', rid: 'sans-forme-connue'),
  ];

  group('parseRiftboundId', () {
    test('décompose set, numéro, étoile et total', () {
      final parsed = parseRiftboundId('unl-229*-219')!;
      expect(parsed.set, 'UNL');
      expect(parsed.number, 229);
      expect(parsed.total, 219);
      expect(parsed.star, isTrue);
    });

    test('identifiant hors forme : null', () {
      expect(parseRiftboundId('sans-forme-connue'), isNull);
      expect(parseRiftboundId(null), isNull);
      expect(parseRiftboundId(''), isNull);
    });
  });

  test('collectorTotals ignore les identifiants illisibles', () {
    expect(collectorTotals(index), {298, 219});
  });

  group('parseCollectorCode', () {
    test('ligne propre « OGN 209/298 »', () {
      final code = parseCollectorCode('OGN 209/298', totals)!;
      expect(code.set, 'OGN');
      expect(code.number, 209);
      expect(code.total, 298);
      expect(code.star, isFalse);
      expect(code.label, 'OGN 209/298');
    });

    test('ligne bruitée : le code en fin de ligne l’emporte', () {
      final code = parseCollectorCode('4 ★ Rare — UNL • 229 / 219', totals)!;
      expect(code.set, 'UNL');
      expect(code.number, 229);
      expect(code.total, 219);
    });

    test('minuscules et point médian perdu', () {
      final code = parseCollectorCode('ogn 002 298', totals)!;
      expect(code.set, 'OGN');
      expect(code.number, 2);
      expect(code.label, 'OGN 002/298');
    });

    test('confusions O/0 et I/1 corrigées dans les blocs numériques', () {
      final code = parseCollectorCode('OGN 2O9/29B', {298, 219});
      // « 29B » n’est pas normalisé (B n’est pas une confusion traitée) : la
      // paire (2O9, 29B) est refusée, aucune autre n’existe.
      expect(code, isNull);

      final fixed = parseCollectorCode('OGN 2O9/298', totals)!;
      expect(fixed.number, 209);
      expect(fixed.set, 'OGN', reason: 'le set ne doit pas être normalisé');

      final unl = parseCollectorCode('UNL 229/2I9', totals)!;
      expect(unl.total, 219);
    });

    test('étoile lue entre les deux nombres', () {
      final code = parseCollectorCode('OGN 209*/298', totals)!;
      expect(code.star, isTrue);
      expect(code.label, 'OGN 209*/298');
    });

    test('nombres collés : les totaux connus donnent la coupure', () {
      final code = parseCollectorCode('UNL 229219', totals)!;
      expect(code.number, 229);
      expect(code.total, 219);
      expect(code.star, isFalse);
    });

    test('total inconnu : lecture refusée', () {
      expect(parseCollectorCode('OGN 209/279', totals), isNull);
    });

    test('numéro invraisemblable : lecture refusée', () {
      expect(parseCollectorCode('OGN 999/298', totals), isNull);
      expect(parseCollectorCode('OGN 0/298', totals), isNull);
    });

    test('numéro au-delà du total mais dans la marge : accepté', () {
      final code = parseCollectorCode('OGN 320/298', totals)!;
      expect(code.number, 320);
      expect(
        parseCollectorCode('OGN ${298 + kOvernumberMargin + 1}/298', totals),
        isNull,
      );
    });

    test('sans totaux connus, rien n’est accepté', () {
      expect(parseCollectorCode('OGN 209/298', const {}), isNull);
    });

    test('texte sans chiffres exploitables', () {
      expect(
        parseCollectorCode('Jinx, la fauteuse de troubles', totals),
        isNull,
      );
      expect(parseCollectorCode(null, totals), isNull);
    });
  });

  group('parseCollectorCodeFromLines', () {
    test('la première ligne crédible gagne', () {
      final code = parseCollectorCodeFromLines(const [
        'OGN 209/298',
        'Illustration : Riot Games',
      ], totals)!;
      expect(code.number, 209);
    });

    test('le texte de règles ne fabrique pas un code', () {
      expect(
        parseCollectorCodeFromLines(const [
          'Inflige 3 dégâts',
          'Puissance 298',
        ], totals),
        isNull,
        reason: 'aucune ligne ne porte à elle seule un couple numéro/total',
      );
    });
  });

  group('matchByCode', () {
    test('le set départage les extensions', () {
      final matches = matchByCode(
        const CollectorCode(set: 'UNL', number: 229, total: 219),
        index,
      );
      expect(matches.map((entry) => entry.id), ['UNL-229']);
    });

    test('étoile lue : la variante étoilée passe devant, sans filtrer', () {
      final matches = matchByCode(
        const CollectorCode(set: 'OGN', number: 209, total: 298, star: true),
        index,
      );
      expect(matches.map((entry) => entry.id), ['OGN-209s', 'OGN-209']);
    });

    test('sans étoile : l’ordre de l’index est conservé', () {
      final matches = matchByCode(
        const CollectorCode(set: 'OGN', number: 209, total: 298),
        index,
      );
      expect(matches.map((entry) => entry.id), ['OGN-209', 'OGN-209s']);
    });

    test('set mal lu : repli sur le numéro seul', () {
      final matches = matchByCode(
        const CollectorCode(set: 'QGN', number: 209, total: 298),
        index,
      );
      expect(matches.map((entry) => entry.id), ['OGN-209', 'OGN-209s']);
    });

    test('code inconnu : aucune carte', () {
      expect(
        matchByCode(const CollectorCode(number: 7, total: 298), index),
        isEmpty,
      );
      expect(matchByCode(null, index), isEmpty);
    });
  });
}
