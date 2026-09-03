import 'dart:async';

/// Sondage périodique tolérant aux coupures.
///
/// Le serveur ne pousse rien : les écrans de partie suivie redemandent
/// régulièrement l'état. Cette petite mécanique évite trois pièges du
/// `Timer.periodic` nu :
///
/// - **appel en vol** : si un battement dure plus longtemps que l'intervalle,
///   le suivant est sauté plutôt que de s'empiler ;
/// - **réseau en panne** : chaque échec double l'attente (jusqu'à
///   [maxInterval]) ; le premier succès revient à la cadence nominale ;
/// - **application en arrière-plan** : [pause] suspend les battements,
///   [resume] en déclenche un tout de suite puis reprend la cadence.
///
/// Un [tick] qui lève est lu comme un échec : c'est ce qui déclenche le
/// ralentissement. Un intervalle nul (ou négatif) n'arme jamais de minuteur :
/// les tests appellent alors les rafraîchissements à la main.
class Poller {
  Poller({
    required this.tick,
    this.interval = const Duration(seconds: 2),
    Duration? maxInterval,
  }) : maxInterval = maxInterval ?? interval * 15;

  /// Un battement.
  final Future<void> Function() tick;

  /// Cadence nominale.
  final Duration interval;

  /// Attente maximale après une suite d'échecs.
  final Duration maxInterval;

  Timer? _timer;
  Duration _delay = Duration.zero;
  bool _inFlight = false;
  bool _started = false;
  bool _paused = false;
  bool _disposed = false;

  /// Attente avant le prochain battement (visible pour les tests).
  Duration get delay => _delay;

  /// Des battements sont attendus (démarré et non suspendu).
  bool get isRunning => _started && !_paused && !_disposed;

  /// Démarre (ou redémarre) le sondage à la cadence nominale.
  void start() {
    if (_disposed || interval <= Duration.zero) return;
    _started = true;
    _paused = false;
    _delay = interval;
    _arm();
  }

  /// Arrête définitivement les battements (salon fermé, match terminé).
  void stop() {
    _started = false;
    _paused = false;
    _timer?.cancel();
    _timer = null;
  }

  /// Suspend les battements sans oublier qu'on sondait (app en arrière-plan).
  void pause() {
    if (!_started || _paused) return;
    _paused = true;
    _timer?.cancel();
    _timer = null;
  }

  /// Reprend après [pause] : un battement part tout de suite.
  void resume() {
    if (_disposed || !_started || !_paused) return;
    _paused = false;
    _delay = interval;
    _beat();
  }

  void dispose() {
    _disposed = true;
    stop();
  }

  void _arm() {
    _timer?.cancel();
    _timer = _delay <= Duration.zero ? null : Timer(_delay, _beat);
  }

  Future<void> _beat() async {
    if (!isRunning) return;
    if (_inFlight) {
      // Le battement précédent tourne encore : celui-ci est sauté.
      _arm();
      return;
    }
    _inFlight = true;
    var failed = false;
    try {
      await tick();
    } catch (_) {
      failed = true;
    } finally {
      _inFlight = false;
    }
    if (!isRunning) return;
    _delay = failed ? _slower() : interval;
    _arm();
  }

  Duration _slower() {
    final next = _delay <= Duration.zero ? interval : _delay * 2;
    return next > maxInterval ? maxInterval : next;
  }
}
