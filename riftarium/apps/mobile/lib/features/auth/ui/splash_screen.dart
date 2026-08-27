import 'package:flutter/material.dart';

import '../../../app/design/components.dart';
import '../../../app/theme.dart';

/// Affiché pendant la restauration de la session au démarrage.
///
/// Rideau encre traversé d'une lueur dorée : le logo-mot apparaît, le filet or
/// s'étire sous lui en 600 ms. Aucune image réseau : l'écran doit s'afficher
/// avant même que la première requête parte.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: RiftMotion.ease,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (_controller.isDismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiftColors.inkStrong,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 0.9,
            colors: [
              RiftColors.gold.withValues(alpha: 0.26),
              RiftColors.gold.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) {
              final t = _curve.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - t)),
                      child: child,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GoldRule(width: 28 + 132 * t),
                  const SizedBox(height: 34),
                  Opacity(
                    opacity: 0.5 * t,
                    child: const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: RiftColors.goldSoft,
                      ),
                    ),
                  ),
                ],
              );
            },
            child: const Text(
              'Riftarium',
              style: TextStyle(
                fontFamily: RiftFonts.display,
                fontSize: 34,
                height: 1.1,
                letterSpacing: 1.4,
                color: RiftColors.goldSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
