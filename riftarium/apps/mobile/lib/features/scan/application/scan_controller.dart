import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../../core/api_exception.dart';
import '../../cards/application/cards_controller.dart';
import '../../cards/data/cards_api.dart';
import '../../cards/domain/card.dart';
import '../../collection/application/card_collection_controller.dart';
import '../../collection/application/collection_controller.dart';
import '../data/scan_collection_api.dart';
import '../data/scan_index.dart';
import '../domain/collector_code.dart';
import 'camera_frame.dart';

/// Caméras de l'appareil. Passe par un provider pour que les tests puissent en
/// simuler l'absence : `availableCameras()` appelle un plugin natif, indisponible
/// sous `flutter test`.
typedef CamerasLookup = Future<List<CameraDescription>> Function();

/// Fabrique du contrôleur caméra (même raison).
typedef CameraControllerFactory =
    CameraController Function(CameraDescription description);

/// Fabrique du moteur de reconnaissance de texte (même raison).
typedef TextRecognizerFactory = TextRecognizer Function();

final camerasLookupProvider = Provider<CamerasLookup>(
  (ref) => availableCameras,
);

final cameraControllerFactoryProvider = Provider<CameraControllerFactory>(
  (ref) =>
      (description) => CameraController(
        description,
        // La haute définition suffit largement pour un code de quelques
        // millimètres et laisse le processeur au moteur de reconnaissance.
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: scanImageFormat,
      ),
);

final textRecognizerFactoryProvider = Provider<TextRecognizerFactory>(
  (ref) =>
      () => TextRecognizer(script: TextRecognitionScript.latin),
);

/// Étapes de l'écran de scan.
enum ScanStage {
  /// Ouverture de la caméra et chargement de l'index.
  initializing,

  /// Aucune caméra sur l'appareil (émulateur, tablette sans capteur).
  noCamera,

  /// L'utilisateur a refusé l'accès à la caméra.
  permissionDenied,

  /// Panne bloquante (caméra ou index) : rien à scanner tant qu'on n'a pas
  /// réessayé.
  failed,

  /// Boucle active : la caméra tourne, chaque image est analysée.
  scanning,

  /// Une carte est verrouillée et affichée dans la feuille de résultat.
  recognized,
}

/// Carte reconnue pendant la session, telle qu'affichée dans l'historique.
@immutable
class ScanHistoryEntry {
  const ScanHistoryEntry({
    required this.card,
    required this.code,
    this.addedQty = 0,
  });

  final RiftCard card;
  final String code;

  /// Exemplaires ajoutés à la collection depuis cet écran : le cumul en euros
  /// du bandeau compte ce qui a réellement été rangé, pas une carte vue.
  final int addedQty;

  ScanHistoryEntry copyWith({RiftCard? card, int? addedQty}) =>
      ScanHistoryEntry(
        card: card ?? this.card,
        code: code,
        addedQty: addedQty ?? this.addedQty,
      );
}

@immutable
class ScanState {
  const ScanState({
    this.stage = ScanStage.initializing,
    this.message,
    this.card,
    this.code,
    this.addedQty = 0,
    this.adding = false,
    this.addError,
    this.torchOn = false,
    this.reading = false,
    this.history = const [],
  });

  final ScanStage stage;

  /// Message d'erreur global (caméra, index, chargement de la carte).
  final String? message;

  /// Carte verrouillée. Null pendant son chargement, juste après la lecture.
  final RiftCard? card;

  /// Code lu, tel qu'imprimé (« OGN 209/298 »).
  final String? code;

  /// Exemplaires ajoutés à la collection depuis cet écran de résultat.
  final int addedQty;
  final bool adding;
  final String? addError;

  final bool torchOn;

  /// Un code est en cours de confirmation : l'écran annonce « Lecture… ».
  final bool reading;

  /// Cartes reconnues pendant la session, la plus récente en tête.
  final List<ScanHistoryEntry> history;

  bool get isBusy => stage == ScanStage.initializing;
  bool get isLive =>
      stage == ScanStage.scanning || stage == ScanStage.recognized;

  ScanState copyWith({
    ScanStage? stage,
    String? message,
    RiftCard? card,
    String? code,
    int? addedQty,
    bool? adding,
    String? addError,
    bool? torchOn,
    bool? reading,
    List<ScanHistoryEntry>? history,
    bool clearMessage = false,
    bool clearCard = false,
    bool clearCode = false,
    bool clearAddError = false,
  }) => ScanState(
    stage: stage ?? this.stage,
    message: clearMessage ? null : (message ?? this.message),
    card: clearCard ? null : (card ?? this.card),
    code: clearCode ? null : (code ?? this.code),
    addedQty: addedQty ?? this.addedQty,
    adding: adding ?? this.adding,
    addError: clearAddError ? null : (addError ?? this.addError),
    torchOn: torchOn ?? this.torchOn,
    reading: reading ?? this.reading,
    history: history ?? this.history,
  );
}

/// Boucle du scanner : caméra → reconnaissance de texte → code collector →
/// carte, puis ajout à la collection.
///
/// `autoDispose` est essentiel : la caméra et le moteur ML Kit sont libérés dès
/// que l'écran est quitté, sinon le capteur reste allumé en arrière-plan.
final scanControllerProvider =
    NotifierProvider.autoDispose<ScanController, ScanState>(ScanController.new);

class ScanController extends AutoDisposeNotifier<ScanState>
    with WidgetsBindingObserver {
  /// Une analyse toutes les 300 ms au plus, et jamais deux en parallèle : le
  /// moteur ML Kit coûte 100 à 300 ms et monopoliserait le flux caméra.
  static const Duration analysisInterval = Duration(milliseconds: 300);

  /// Nombre d'analyses sans code avant d'éteindre « Lecture… » : sans ce
  /// palier, le bandeau clignoterait à chaque image.
  static const int _readingGrace = 3;

  CameraController? _camera;
  TextRecognizer? _recognizer;
  ScanIndex? _index;
  final ScanStabilizer _stabilizer = ScanStabilizer();

  bool _closed = false;
  bool _analysing = false;
  bool _observing = false;
  int _misses = 0;
  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);

  /// Contrôleur caméra pour l'aperçu, null tant qu'il n'est pas prêt.
  CameraController? get camera => _camera;

  @override
  ScanState build() {
    ref.onDispose(_teardown);
    // Démarrage hors du build : pas d'effet de bord synchrone (cf. AuthController).
    Future.microtask(start);
    return const ScanState();
  }

  /// Ouvre la caméra, charge l'index et lance la boucle d'analyse.
  Future<void> start() async {
    List<CameraDescription> cameras;
    try {
      cameras = await ref.read(camerasLookupProvider)();
    } on CameraException catch (error) {
      _failFromCamera(error);
      return;
    } catch (_) {
      _set(
        state.copyWith(
          stage: ScanStage.noCamera,
          message: 'Caméra indisponible sur cet appareil.',
        ),
      );
      return;
    }
    if (_closed) return;
    if (cameras.isEmpty) {
      _set(
        state.copyWith(
          stage: ScanStage.noCamera,
          message: 'Aucune caméra détectée sur cet appareil.',
        ),
      );
      return;
    }

    final description = cameras.firstWhere(
      (item) => item.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final camera = ref.read(cameraControllerFactoryProvider)(description);
    try {
      await camera.initialize();
    } on CameraException catch (error) {
      await camera.dispose();
      _failFromCamera(error);
      return;
    }
    if (_closed) {
      await camera.dispose();
      return;
    }

    _camera = camera;
    _recognizer = ref.read(textRecognizerFactoryProvider)();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _set(state.copyWith(stage: ScanStage.scanning, clearMessage: true));
    await _loadIndex();
    if (_closed) return;
    await _startStream();
  }

  Future<void> _loadIndex() async {
    try {
      final index = await ref.read(scanIndexProvider.future);
      if (_closed) return;
      if (!index.isUsable) {
        _set(
          state.copyWith(
            stage: ScanStage.failed,
            message: 'La cartothèque est vide : rien à reconnaître.',
          ),
        );
        return;
      }
      _index = index;
    } on ApiException catch (error) {
      if (_closed) return;
      _set(state.copyWith(stage: ScanStage.failed, message: error.message));
    }
  }

  Future<void> _startStream() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    if (camera.value.isStreamingImages) return;
    try {
      await camera.startImageStream(_onFrame);
    } on CameraException catch (error) {
      if (_closed) return;
      _failFromCamera(error);
    }
  }

  Future<void> _stopStream() async {
    final camera = _camera;
    if (camera == null || !camera.value.isStreamingImages) return;
    try {
      await camera.stopImageStream();
    } on CameraException {
      // Flux déjà coupé par le système : rien à libérer.
    }
    // Le système éteint la torche avec le capteur : l'icône ne doit pas rester
    // allumée pendant que la caméra dort.
    if (!_closed && state.torchOn) _set(state.copyWith(torchOn: false));
  }

  /// Analyse d'une image du flux. Volontairement tolérante : une image floue ou
  /// une carte de travers ne sont pas des pannes, on retentera à la suivante.
  Future<void> _onFrame(CameraImage image) async {
    if (_closed || _analysing) return;
    if (state.stage != ScanStage.scanning) return;
    final index = _index;
    final recognizer = _recognizer;
    final camera = _camera;
    if (index == null || recognizer == null || camera == null) return;

    final now = DateTime.now();
    if (now.difference(_lastAnalysis) < analysisInterval) return;
    final input = inputImageFrom(
      image,
      description: camera.description,
      deviceOrientation: camera.value.deviceOrientation,
    );
    if (input == null) return;

    _analysing = true;
    _lastAnalysis = now;
    try {
      final recognized = await recognizer.processImage(input);
      if (_closed || state.stage != ScanStage.scanning) return;
      final code = index.read(linesFromBottom(recognized));
      final entry = code == null ? null : index.resolve(code);
      if (code == null || entry == null) {
        _noteMiss();
        return;
      }
      _misses = 0;
      if (!state.reading) _set(state.copyWith(reading: true));
      if (_stabilizer.offer(entry.id) == null) return;
      await _lock(entry.id, code);
    } catch (_) {
      _noteMiss();
    } finally {
      _analysing = false;
    }
  }

  void _noteMiss() {
    _misses++;
    if (_misses >= _readingGrace && state.reading) {
      _set(state.copyWith(reading: false));
    }
  }

  /// Carte confirmée : on gèle l'analyse et on charge la fiche complète (prix,
  /// visuel, quantité possédée).
  Future<void> _lock(String cardId, CollectorCode code) async {
    _misses = 0;
    _set(
      state.copyWith(
        stage: ScanStage.recognized,
        code: code.label,
        reading: false,
        addedQty: 0,
        clearCard: true,
        clearAddError: true,
        clearMessage: true,
      ),
    );
    await HapticFeedback.selectionClick();
    try {
      final card = await ref.read(cardsApiProvider).get(cardId);
      if (_closed || state.stage != ScanStage.recognized) return;
      _set(state.copyWith(card: card, history: _pushHistory(card, code.label)));
    } on ApiException catch (error) {
      if (_closed) return;
      // Sans carte à montrer, la feuille de résultat n'a rien à afficher et ses
      // boutons de reprise vivent dedans : on repart en scan avec le message.
      _set(
        state.copyWith(
          stage: ScanStage.scanning,
          message: error.message,
          clearCode: true,
        ),
      );
    }
  }

  List<ScanHistoryEntry> _pushHistory(RiftCard card, String code) {
    final history = [
      ScanHistoryEntry(card: card, code: code),
      ...state.history.where((entry) => entry.card.id != card.id),
    ];
    return history.length > 12 ? history.sublist(0, 12) : history;
  }

  /// « +N dans ma collection » : ajoute la quantité choisie et met à jour la
  /// quantité possédée affichée.
  Future<void> add([int qty = 1]) async {
    final card = state.card;
    if (card == null || state.adding || qty < 1) return;
    _set(state.copyWith(adding: true, clearAddError: true));
    try {
      final total = await ref
          .read(scanCollectionApiProvider)
          .add(card.id, qty: qty);
      if (_closed) return;
      final updated = card.copyWith(ownedQty: total);
      _set(
        state.copyWith(
          card: updated,
          adding: false,
          addedQty: state.addedQty + qty,
          history: [
            for (final entry in state.history)
              if (entry.card.id == updated.id)
                entry.copyWith(card: updated, addedQty: entry.addedQty + qty)
              else
                entry,
          ],
        ),
      );
      // La collection, la progression par set, la fiche de cette carte et la
      // cartothèque affichent tous cette quantité : elles repartiront du
      // serveur à leur prochaine lecture.
      ref.invalidate(collectionControllerProvider);
      ref.invalidate(collectionProgressProvider);
      ref.invalidate(cardCollectionProvider(card.id));
      ref.invalidate(cardsListProvider);
      await HapticFeedback.mediumImpact();
    } on ApiException catch (error) {
      if (_closed) return;
      _set(state.copyWith(adding: false, addError: error.message));
    }
  }

  /// « Scanner la suivante » : referme le résultat et relance l'analyse. La
  /// carte qui vient d'être reconnue reste ignorée le temps du délai
  /// d'anti-doublon, sans quoi elle serait immédiatement reverrouillée.
  void scanNext() {
    if (_closed || !state.isLive) return;
    _stabilizer.clearPending();
    _misses = 0;
    _set(
      state.copyWith(
        stage: ScanStage.scanning,
        reading: false,
        addedQty: 0,
        clearCard: true,
        clearCode: true,
        clearAddError: true,
        clearMessage: true,
      ),
    );
  }

  Future<void> toggleTorch() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) return;
    final next = !state.torchOn;
    try {
      await camera.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (!_closed) _set(state.copyWith(torchOn: next));
    } on CameraException {
      if (!_closed) {
        _set(state.copyWith(message: 'Torche indisponible sur cet appareil.'));
      }
    }
  }

  /// Nouvel essai après une panne : recharge l'index si la caméra est déjà là,
  /// sinon reprend tout depuis le début.
  Future<void> retry() async {
    if (_closed) return;
    if (_camera == null) {
      _set(const ScanState());
      await start();
      return;
    }
    _set(state.copyWith(stage: ScanStage.scanning, clearMessage: true));
    ref.invalidate(scanIndexProvider);
    await _loadIndex();
    if (_closed) return;
    await _startStream();
  }

  /// Le paramètre s'appelle `state` pour respecter la signature de
  /// [WidgetsBindingObserver] : il masque volontairement l'état du notifier,
  /// dont cette méthode n'a pas besoin.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_closed) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Application en arrière-plan : le système peut reprendre le capteur,
        // et laisser tourner l'analyse ne ferait que vider la batterie.
        unawaited(_stopStream());
      case AppLifecycleState.resumed:
        // Sur une panne, un refus de permission ou un appareil sans capteur,
        // il n'y a rien à relancer : l'écran attend un nouvel essai explicite.
        switch (this.state.stage) {
          case ScanStage.failed:
          case ScanStage.permissionDenied:
          case ScanStage.noCamera:
            return;
          case ScanStage.initializing:
          case ScanStage.scanning:
          case ScanStage.recognized:
            unawaited(_startStream());
        }
    }
  }

  void _failFromCamera(CameraException error) {
    if (_closed) return;
    final denied = error.code.toLowerCase().contains('accessdenied');
    _set(
      denied
          ? state.copyWith(
              stage: ScanStage.permissionDenied,
              clearMessage: true,
            )
          : state.copyWith(
              stage: ScanStage.failed,
              message: error.description ?? 'La caméra n’a pas pu démarrer.',
            ),
    );
  }

  /// Affectation protégée : après la libération du provider, écrire dans
  /// `state` lèverait une erreur (une analyse peut encore être en vol).
  void _set(ScanState next) {
    if (_closed) return;
    state = next;
  }

  Future<void> _teardown() async {
    _closed = true;
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    final camera = _camera;
    final recognizer = _recognizer;
    _camera = null;
    _recognizer = null;
    if (camera != null) {
      try {
        if (camera.value.isStreamingImages) await camera.stopImageStream();
      } on CameraException {
        // Le flux peut déjà être coupé : la libération continue.
      }
      await camera.dispose();
    }
    await recognizer?.close();
  }
}
