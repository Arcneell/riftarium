import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/scan/domain/collector_code.dart';

void main() {
  // Deux extensions, comme en production : les totaux d'impression sont la
  // seule chose qui distingue une lecture crédible d'un nombre inventé.
  const totals = {219, 298};

  const entries = [
    ScanIndexEntry(id: 'OGN-209', rid: 'ogn-209-298'),
    ScanIndexEntry(id: 'OGN-209s', rid: 'ogn-209*-298'),
    // L'alt-art déclaré avant la base : la préférence de suffixe doit primer
    // sur l'ordre de l'index.
    ScanIndexEntry(id: 'OGN-007a', rid: 'ogn-007a-298'),
    ScanIndexEntry(id: 'OGN-007', rid: 'ogn-007-298'),
    ScanIndexEntry(id: 'UNL-229', rid: 'unl-229-219'),
    ScanIndexEntry(id: 'PROMO', rid: 'sans-forme-connue'),
  ];

  // L'index est pré-parsé une fois : c'est ce que fait ScanIndex au chargement.
  final index = CollectorIndex(entries);

  group('parseRiftboundId', () {
    test('décompose set, numéro, étoile et total', () {
      final parsed = parseRiftboundId('unl-229*-219')!;
      expect(parsed.set, 'UNL');
      expect(parsed.number, 229);
      expect(parsed.total, 219);
      expect(parsed.suffix, '*');
    });

    test('identifiant hors forme : null', () {
      expect(parseRiftboundId('sans-forme-connue'), isNull);
      expect(parseRiftboundId(null), isNull);
      expect(parseRiftboundId(''), isNull);
    });
  });

  test('les totaux ignorent les identifiants illisibles', () {
    expect(index.totals, {298, 219});
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

    test('lettre d’alt-art lue entre le numéro et le total', () {
      final code = parseCollectorCode('OGN 007A/298', totals)!;
      expect(code.number, 7);
      expect(code.suffix, 'a');
      expect(code.star, isFalse);
      expect(code.label, 'OGN 007a/298');

      // Lettre séparée par des espaces : toujours un suffixe.
      final spaced = parseCollectorCode('OGN 007 A 298', totals)!;
      expect(spaced.suffix, 'a');
    });

    test('un mot entre les nombres n’est pas un suffixe', () {
      final code = parseCollectorCode('OGN 209 RARE 298', totals)!;
      expect(code.suffix, '');
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

  group('CollectorIndex.match', () {
    test('le set départage les extensions', () {
      final matches = index.match(
        const CollectorCode(set: 'UNL', number: 229, total: 219),
      );
      expect(matches.map((entry) => entry.id), ['UNL-229']);
    });

    test('étoile lue : la variante étoilée passe devant, sans filtrer', () {
      final matches = index.match(
        const CollectorCode(set: 'OGN', number: 209, total: 298, suffix: '*'),
      );
      expect(matches.map((entry) => entry.id), ['OGN-209s', 'OGN-209']);
    });

    test('lettre lue : l’art alternatif passe devant la base', () {
      final matches = index.match(
        const CollectorCode(set: 'OGN', number: 7, total: 298, suffix: 'a'),
      );
      expect(matches.map((entry) => entry.id), ['OGN-007a', 'OGN-007']);
    });

    test('sans suffixe lu : la base passe devant l’alt, quel que soit l’ordre '
        'de l’index', () {
      final matches = index.match(
        const CollectorCode(set: 'OGN', number: 7, total: 298),
      );
      expect(matches.map((entry) => entry.id), ['OGN-007', 'OGN-007a']);
    });

    test('sans étoile : l’ordre de l’index est conservé', () {
      final matches = index.match(
        const CollectorCode(set: 'OGN', number: 209, total: 298),
      );
      expect(matches.map((entry) => entry.id), ['OGN-209', 'OGN-209s']);
    });

    test('set mal lu : repli sur le numéro seul', () {
      final matches = index.match(
        const CollectorCode(set: 'QGN', number: 209, total: 298),
      );
      expect(matches.map((entry) => entry.id), ['OGN-209', 'OGN-209s']);
    });

    test('code inconnu : aucune carte', () {
      expect(index.match(const CollectorCode(number: 8, total: 298)), isEmpty);
      expect(index.match(null), isEmpty);
    });
  });
}
