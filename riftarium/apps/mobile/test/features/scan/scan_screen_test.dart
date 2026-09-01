import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/app/theme.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/scan/application/scan_controller.dart';
import 'package:riftarium_mobile/features/scan/ui/scan_result_sheet.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart';
import 'scan_fixtures.dart';

/// Contrôleur figé sur un état fabriqué : la caméra réelle n'est pas testable,
/// mais tout ce qui l'entoure (bandeau, feuille de résultat, écrans d'erreur)
/// doit l'être.
class _FrozenScanController extends ScanController {
  _FrozenScanController(this._initial);

  final ScanState _initial;
  int addCalls = 0;
  int nextCalls = 0;

  @override
  ScanState build() => _initial;

  @override
  CameraController? get camera => null;

  @override
  Future<void> addOne() async {
    addCalls++;
    state = state.copyWith(addedQty: state.addedQty + 1);
  }

  /// Pousse un état fabriqué depuis le test.
  void push(ScanState next) => state = next;

  @override
  void scanNext() {
    nextCalls++;
    state = state.copyWith(stage: ScanStage.scanning, clearCard: true);
  }
}

void main() {
  late FakeHttpAdapter adapter;
  late InMemoryTokenStore store;

  /// La scène de scan anime en continu (mire dorée, reflet foil de la carte
  /// reconnue) : sans réduction de mouvement, `pumpAndSettle` n'aurait jamais
  /// de fin. Les briques de la charte respectent toutes ce réglage.
  Widget reduceMotion(Widget child) => MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: child,
  );

  Widget app({List<Override> overrides = const []}) => reduceMotion(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(AppRoutes.scan),
        dioProvider.overrideWith(
          (ref) => createApiClient(
            readToken: store.read,
            baseUrl: 'https://api.test/api',
            adapter: adapter,
          ),
        ),
        // Aucune caméra par défaut : `availableCameras()` appelle un plugin
        // natif absent de l'environnement de test.
        camerasLookupProvider.overrideWithValue(
          () async => <CameraDescription>[],
        ),
        ...overrides,
      ],
      child: const RiftariumApp(),
    ),
  );

  setUp(() {
    store = InMemoryTokenStore('jwt');
    adapter = FakeHttpAdapter({
      'GET /auth/me': const FakeResponse(200, profileJson),
    });
  });

  group('ScanScreen', () {
    testWidgets('sans caméra, l’écran l’explique et propose de fermer', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      expect(find.text('Aucune caméra'), findsOneWidget);
      expect(find.text('Fermer'), findsOneWidget);
      expect(find.text('Cadre le code de la carte'), findsNothing);
    });

    testWidgets('permission refusée : instruction vers les réglages', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          overrides: [
            scanControllerProvider.overrideWith(
              () => _FrozenScanController(
                const ScanState(stage: ScanStage.permissionDenied),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accès à la caméra refusé'), findsOneWidget);
      expect(find.textContaining('réglages du téléphone'), findsOneWidget);
    });

    testWidgets('panne : message de l’API et bouton Réessayer', (tester) async {
      await tester.pumpWidget(
        app(
          overrides: [
            scanControllerProvider.overrideWith(
              () => _FrozenScanController(
                const ScanState(
                  stage: ScanStage.failed,
                  message: 'Index en panne',
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Scan indisponible'), findsOneWidget);
      expect(find.text('Index en panne'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('scan en cours : cadre-guide et bandeau d’invite', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          overrides: [
            scanControllerProvider.overrideWith(
              () => _FrozenScanController(
                const ScanState(stage: ScanStage.scanning),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cadre le code de la carte'), findsOneWidget);
    });

    testWidgets('lecture en cours : le bandeau change', (tester) async {
      await tester.pumpWidget(
        app(
          overrides: [
            scanControllerProvider.overrideWith(
              () => _FrozenScanController(
                const ScanState(stage: ScanStage.scanning, reading: true),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lecture…'), findsOneWidget);
    });

    testWidgets('carte reconnue : feuille de résultat, ajout, puis suivante', (
      tester,
    ) async {
      final card = scanCard();
      final controller = _FrozenScanController(
        ScanState(
          stage: ScanStage.recognized,
          card: card,
          code: 'OGN 209/298',
          history: [ScanHistoryEntry(card: card, code: 'OGN 209/298')],
        ),
      );
      await tester.pumpWidget(
        app(overrides: [scanControllerProvider.overrideWith(() => controller)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Carte reconnue'), findsOneWidget);
      expect(find.byType(ScanResultSheet), findsOneWidget);
      expect(find.text('Jinx, la fauteuse de troubles'), findsWidgets);
      expect(find.text('OGN 209/298'), findsOneWidget);
      expect(find.text('Prix estimé 12,34\u00A0€'), findsOneWidget);
      expect(find.text('Dans ta collection : 1'), findsOneWidget);

      await tester.tap(find.text('+1 dans ma collection'));
      await tester.pumpAndSettle();
      expect(controller.addCalls, 1);
      expect(find.text('1 exemplaire ajouté.'), findsOneWidget);

      await tester.tap(find.text('Scanner la suivante'));
      await tester.pumpAndSettle();
      expect(controller.nextCalls, 1);
      expect(find.byType(ScanResultSheet), findsNothing);
      // La carte reste dans la rangée des dernières cartes scannées.
      expect(find.text('Cadre le code de la carte'), findsOneWidget);
      expect(find.text('Jinx, la fauteuse de troubles'), findsOneWidget);
    });

    testWidgets('carte en cours de chargement : indicateur, pas de feuille', (
      tester,
    ) async {
      final controller = _FrozenScanController(
        const ScanState(stage: ScanStage.scanning),
      );
      await tester.pumpWidget(
        app(overrides: [scanControllerProvider.overrideWith(() => controller)]),
      );
      await tester.pumpAndSettle();

      // Le code vient d'être verrouillé, la fiche n'est pas encore arrivée.
      controller.push(
        const ScanState(stage: ScanStage.recognized, code: 'OGN 209/298'),
      );
      await tester.pump();

      expect(find.byType(ScanResultSheet), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('ScanResultSheet', () {
    Widget sheet(Widget child) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: child),
        ),
      ),
    );

    testWidgets('carte jamais possédée, sans prix connu', (tester) async {
      await tester.pumpWidget(
        sheet(
          ScanResultSheet(
            card: scanCard(priceEur: null, ownedQty: 0),
            code: 'OGN 209/298',
            addedQty: 0,
            adding: false,
            addError: null,
            onAdd: () {},
            onOpenCard: () {},
            onNext: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Prix estimé indisponible'), findsOneWidget);
      expect(find.text('Pas encore dans ta collection'), findsOneWidget);
    });

    testWidgets('erreur d’ajout affichée sous la carte', (tester) async {
      await tester.pumpWidget(
        sheet(
          ScanResultSheet(
            card: scanCard(),
            code: 'OGN 209/298',
            addedQty: 0,
            adding: false,
            addError: 'Pas de connexion. Vérifie ton réseau.',
            onAdd: () {},
            onOpenCard: () {},
            onNext: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('Pas de connexion. Vérifie ton réseau.'),
        findsOneWidget,
      );
    });

    testWidgets('« Fiche » déclenche l’ouverture de la carte', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        sheet(
          ScanResultSheet(
            card: scanCard(),
            code: 'OGN 209/298',
            addedQty: 2,
            adding: false,
            addError: null,
            onAdd: () {},
            onOpenCard: () => opened++,
            onNext: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('2 exemplaires ajoutés.'), findsOneWidget);
      await tester.tap(find.text('Fiche'));
      expect(opened, 1);
    });
  });
}
