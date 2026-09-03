import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/rules/domain/guides.dart';

import 'guides_fixture.dart';

void main() {
  final document = parseGuidesDocument(kGuidesFixtureSource);

  group('lecture du fichier des guides', () {
    test('les familles et les sujets sont lus dans l’ordre', () {
      expect(document.categories.map((c) => c.key), ['tour', 'combat']);
      expect(document.categoryLabel('tour'), 'Tour & timing');
      expect(document.topics.length, 3);
      expect(document.topics.first.title, 'Le déroulement du tour');
    });

    test('un sujet porte son essentiel, ses cas et ses renvois', () {
      final topic = document.topicBySlug('deroulement-du-tour')!;
      expect(topic.details.length, 2);
      expect(topic.cases.first.question, contains('points d’occupation'));
      expect(topic.cases.first.answer, contains('étape des scores'));
      expect(topic.sections, ['197']);
      expect(topic.demo, isNull);
    });

    test('la démo garde ses images et leurs éléments', () {
      final demo = document.topicBySlug('la-chaine')!.demo!;
      expect(demo.frames.length, 2);
      expect(demo.frames.first.items.first.type, DemoItemType.zone);
      final unit = demo.frames.last.items.last;
      expect(unit.type, DemoItemType.unit);
      expect(unit.isFoe, isTrue);
      // Les valeurs numériques se lisent comme du texte (« 3 », « −4 »).
      expect(unit.value, '3');
    });

    test('les cartes d’exemple sont rattachées au sujet', () {
      final topic = document.topicBySlug('la-chaine')!;
      expect(topic.examples.single.name, 'Get Excited!');
    });

    test('sujet inconnu : null, et le suivant reste calculable', () {
      expect(document.topicBySlug('inconnu'), isNull);
      expect(document.topicAfter('deroulement-du-tour')?.slug, 'la-chaine');
      expect(document.topicAfter('etapes-du-combat'), isNull);
    });
  });

  group('pas à pas du débutant', () {
    test('les étapes portent leur scène et leur renvoi officiel', () {
      expect(document.steps.length, 3);
      final first = document.steps.first;
      expect(first.title, 'Ce qu’il faut pour jouer');
      expect(first.reference, '197');
      expect(first.terms, ['deck principal', 'deck de runes']);
      expect(first.scene.bare, isTrue);
      expect(first.scene.cards.single.glow, isTrue);
      expect(first.scene.cards.single.spot.rotation, -8);
    });

    test('la scène décrit le contrôle, la flèche et la main adverse', () {
      final scene = document.steps[1].scene;
      expect(scene.foeHand, 2);
      expect(scene.controllerOf('bfFoe'), 'you');
      expect(scene.isContested('bfFoe'), isFalse);
      expect(scene.arrow!.from.x, 92);
      expect(scene.arrow!.to.y, 87);
      expect(scene.cards.last.facedown, isTrue);
    });

    test('la dernière scène porte score, jetons, focus et confrontation', () {
      final scene = document.steps.last.scene;
      expect(scene.scoreYou, 8);
      expect(scene.scoreFoe, 4);
      expect(scene.scorePulse, isTrue);
      expect(scene.clash, isTrue);
      expect(scene.isContested('bfFoe'), isTrue);
      expect(scene.chips!.energy, 2);
      expect(scene.chips!.essence, 1);
      expect(scene.focus!.notes.length, 2);
      expect(scene.cards.single.damage, '2');
      expect(scene.cards.single.card.might, 5);
    });

    test('les emplacements et visuels partagés sont indexés', () {
      expect(document.spots['bfFoe']!.x, 39);
      expect(document.boardCards['bfYou']!.name, 'Votre champ');
    });
  });

  group('recherche dans les sujets', () {
    test('une requête trop courte ne renvoie rien', () {
      expect(searchGuideTopics(document, 'a'), isEmpty);
    });

    test('la recherche ignore la casse et les accents', () {
      final hits = searchGuideTopics(document, 'CHAINE');
      expect(hits.single.slug, 'la-chaine');
    });

    test('tous les mots doivent être présents', () {
      expect(searchGuideTopics(document, 'chaine combat'), isEmpty);
    });

    test('un mot du titre passe devant un mot du corps', () {
      final hits = searchGuideTopics(document, 'combat');
      expect(hits.first.slug, 'etapes-du-combat');
    });

    test('la recherche couvre aussi les cas concrets', () {
      final hits = searchGuideTopics(document, 'occupation');
      expect(hits.single.slug, 'deroulement-du-tour');
    });
  });

  group('fichier embarqué', () {
    test('le vrai export se lit en entier', () {
      // Garde-fou sur l'export de `apps/web/src/rules/*.js` : une forme qui
      // change casserait silencieusement les écrans.
      final file = File('assets/rules/guides-fr.json');
      final real = parseGuidesDocument(file.readAsStringSync());

      expect(real.categories, hasLength(6));
      expect(real.topics, hasLength(47));
      expect(real.steps, hasLength(17));
      expect(real.topics.every((topic) => topic.slug.isNotEmpty), isTrue);
      expect(real.topics.every((topic) => topic.details.isNotEmpty), isTrue);
      expect(
        real.steps.every((step) => step.scene.cards.isNotEmpty),
        isTrue,
        reason: 'chaque étape pose au moins une carte sur le plateau',
      );
      expect(real.boardCards['bfYou']?.image, contains('http'));
      expect(real.spots['bfFoe'], isNotNull);
    });
  });
}
