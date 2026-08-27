import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets/card_image.dart';
import '../../domain/guides.dart';
import 'card_zoom.dart';

/// Plateau du guide du débutant : une table de jeu vue de dessus, sur fond
/// d'encre, où les cartes officielles sont posées aux emplacements de la
/// scène. Mêmes proportions que sur le site (repère 160 × 95).
///
/// Tout est exprimé en pourcentage du plateau : le rendu est identique d'un
/// téléphone à une tablette.
class GuideBoard extends StatelessWidget {
  const GuideBoard({
    super.key,
    required this.scene,
    required this.boardCards,
    required this.spots,
  });

  final GuideScene scene;

  /// Visuels partagés par les étapes (champs de bataille notamment).
  final Map<String, GuideCard> boardCards;
  final Map<String, GuideSpot> spots;

  static const double ratio = 160 / 95;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: ratio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.hasBoundedHeight
              ? constraints.maxHeight
              : width / ratio;
          final metrics = _BoardMetrics(width, height);
          return ClipRRect(
            borderRadius: BorderRadius.circular(RiftRadius.md),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF12253C), RiftColors.inkStrong],
                ),
                border: Border.all(
                  color: RiftColors.gold.withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(RiftRadius.md),
              ),
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  if (!scene.bare) ..._furniture(context, metrics),
                  ..._cards(context, metrics),
                  if (scene.arrow != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ArrowPainter(
                          arrow: scene.arrow!,
                          metrics: metrics,
                        ),
                      ),
                    ),
                  if (scene.clash) _clash(metrics),
                  if (scene.chips != null && !scene.chips!.isEmpty)
                    _pool(context, metrics, scene.chips!),
                  if (scene.focus != null) _focus(context, metrics),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------- décor

  List<Widget> _furniture(BuildContext context, _BoardMetrics m) {
    final discard = spots['discard'];
    final foeDiscard = spots['foeDiscard'];
    return [
      _zone(m, left: 21, right: 22, top: 15, height: 14, label: 'Base adverse'),
      _zone(m, left: 22, right: 23, top: 54, height: 14, label: 'Votre base'),
      _zone(
        m,
        left: 14.5,
        right: 52.5,
        top: 71.5,
        height: 15,
        label: 'Runes',
        labelOnTop: true,
      ),
      _zone(
        m,
        left: 51,
        right: 15.5,
        top: 85,
        height: 14.5,
        label: 'Votre main',
        labelOnTop: true,
        tint: RiftColors.hex,
      ),
      if (discard != null) _slot(m, discard, 'Défausse'),
      if (foeDiscard != null) _slot(m, foeDiscard, 'Sa défausse'),
      for (final key in const ['bfFoe', 'bfYou'])
        if (spots[key] != null && boardCards[key] != null)
          _battlefield(context, m, key, spots[key]!, boardCards[key]!),
      if (scene.foeHand > 0) _foeHand(m),
      _scoreTrack(context, m, you: true),
      _scoreTrack(context, m, you: false),
    ];
  }

  Widget _zone(
    _BoardMetrics m, {
    required double left,
    required double right,
    required double top,
    required double height,
    required String label,
    bool labelOnTop = false,
    Color? tint,
  }) {
    final color = (tint ?? RiftColors.goldSoft).withValues(alpha: 0.45);
    return Positioned(
      left: m.x(left),
      top: m.y(top),
      width: m.width - m.x(left) - m.x(right),
      height: m.y(height),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(m.width * 0.02),
        ),
        child: Align(
          alignment: labelOnTop ? Alignment.topLeft : Alignment.bottomLeft,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: m.width * 0.012,
              vertical: m.width * 0.004,
            ),
            child: Text(label.toUpperCase(), style: m.zoneLabel(tint)),
          ),
        ),
      ),
    );
  }

  Widget _slot(_BoardMetrics m, GuideSpot spot, String label) {
    final width = m.width * 0.075;
    final height = width * _cardRatio;
    return Positioned(
      left: m.x(spot.x) - width / 2,
      top: m.y(spot.y) - height / 2,
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: RiftColors.goldSoft.withValues(alpha: 0.4),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(width * 0.1),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: m.zoneLabel(null),
          ),
        ),
      ),
    );
  }

  Widget _battlefield(
    BuildContext context,
    _BoardMetrics m,
    String key,
    GuideSpot spot,
    GuideCard card,
  ) {
    final width = m.width * 0.175;
    final height = width * _wideRatio;
    final contested = scene.isContested(key);
    final controller = scene.controllerOf(key);
    final accent = contested
        ? RiftColors.fury
        : controller == 'you'
        ? RiftColors.hex
        : controller == 'foe'
        ? RiftColors.fury
        : null;
    final flag = contested
        ? 'Contesté'
        : controller == 'you'
        ? 'À vous'
        : controller == 'foe'
        ? 'À lui'
        : null;
    return Positioned(
      left: m.x(spot.x) - width / 2,
      top: m.y(spot.y) - height / 2,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => showGuideCardZoom(context, card),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(m.width * 0.012),
                  border: accent == null
                      ? null
                      : Border.all(color: accent, width: 2),
                  boxShadow: accent == null
                      ? null
                      : [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.45),
                            blurRadius: m.width * 0.03,
                          ),
                        ],
                ),
                child: _BoardImage(
                  url: card.image,
                  name: card.name,
                  radius: m.width * 0.012,
                ),
              ),
            ),
            if (flag != null)
              Positioned(
                top: -m.width * 0.022,
                left: 0,
                right: 0,
                child: Center(
                  child: _Flag(label: flag, color: accent!, m: m),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _foeHand(_BoardMetrics m) {
    final width = m.width * 0.05;
    final height = width * _cardRatio;
    final overlap = width * 0.22;
    final total = width * scene.foeHand - overlap * (scene.foeHand - 1);
    return Positioned(
      left: (m.width - total) / 2,
      top: m.y(1.5),
      width: total,
      height: height,
      child: Stack(
        children: [
          for (var i = 0; i < scene.foeHand; i++)
            Positioned(
              left: i * (width - overlap),
              width: width,
              height: height,
              child: _CardBack(radius: width * 0.12),
            ),
        ],
      ),
    );
  }

  Widget _scoreTrack(
    BuildContext context,
    _BoardMetrics m, {
    required bool you,
  }) {
    final filled = you ? scene.scoreYou : scene.scoreFoe;
    final color = you ? RiftColors.hex : RiftColors.fury;
    final gem = (m.width * 0.022).clamp(6.0, 13.0);
    final gap = gem * 0.45;
    final children = <Widget>[
      RotatedBox(
        quarterTurns: 3,
        child: Text(you ? 'Vous' : 'Lui', style: m.zoneLabel(null)),
      ),
      SizedBox(height: gap),
      for (var i = 1; i <= 8; i++) ...[
        Container(
          width: gem,
          height: gem,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i <= filled ? color : Colors.transparent,
            border: Border.all(
              color: i <= filled
                  ? color
                  : RiftColors.goldSoft.withValues(alpha: 0.4),
              width: 1,
            ),
            boxShadow: scene.scorePulse && i == filled
                ? [BoxShadow(color: color, blurRadius: gem)]
                : null,
          ),
        ),
        if (i < 8) SizedBox(height: gap),
      ],
    ];
    return Positioned(
      left: you ? m.x(1.6) : null,
      right: you ? null : m.x(1.6),
      top: 0,
      bottom: 0,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }

  // ---------------------------------------------------------------- cartes

  List<Widget> _cards(BuildContext context, _BoardMetrics m) => [
    for (final placed in scene.cards)
      if (!placed.dead) _placedCard(context, m, placed),
  ];

  Widget _placedCard(BuildContext context, _BoardMetrics m, PlacedCard placed) {
    final width = placed.wide
        ? m.width * 0.15
        : placed.inHand
        ? m.width * 0.086
        : m.width * 0.072;
    final height = width * (placed.wide ? _wideRatio : _cardRatio);
    final rotation = (placed.spot.rotation ?? 0) + (placed.tapped ? 90 : 0);
    final radius = width * 0.08;

    Widget visual = placed.facedown
        ? _CardBack(radius: radius)
        : _BoardImage(
            url: placed.card.image,
            name: placed.card.name,
            radius: radius,
            glow: placed.glow,
            ghost: placed.ghost,
          );

    visual = Transform.rotate(angle: rotation * math.pi / 180, child: visual);

    return Positioned(
      left: m.x(placed.spot.x) - width / 2,
      top: m.y(placed.spot.y) - height / 2,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: placed.facedown
            ? null
            : () => showGuideCardZoom(context, placed.card),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: visual),
            if (placed.showMight && placed.card.might != null)
              Positioned(
                right: -width * 0.16,
                bottom: -width * 0.12,
                child: _Badge(
                  label: '${placed.card.might}',
                  color: RiftColors.hex,
                  m: m,
                  circle: true,
                ),
              ),
            if (placed.damage.isNotEmpty)
              Positioned(
                left: -width * 0.2,
                top: -width * 0.16,
                child: _Badge(
                  label: '−${placed.damage}',
                  color: RiftColors.fury,
                  m: m,
                ),
              ),
            if (placed.label.isNotEmpty)
              Positioned(
                left: -width * 0.3,
                right: -width * 0.3,
                top: height + m.width * 0.006,
                child: Text(
                  placed.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: m.zoneLabel(null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- surcouches

  Widget _clash(_BoardMetrics m) {
    final spot = spots['bfFoe'];
    if (spot == null) return const SizedBox.shrink();
    final size = m.width * 0.06;
    return Positioned(
      left: m.x(spot.x) - size,
      top: m.y(spot.y - 24) - size / 2,
      width: size * 2,
      child: Text(
        '⚔',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: size, color: RiftColors.goldSoft),
      ),
    );
  }

  Widget _pool(BuildContext context, _BoardMetrics m, SceneChips chips) {
    final size = (m.width * 0.05).clamp(14.0, 28.0);
    return Positioned(
      left: m.x(16),
      top: m.y(68),
      child: Row(
        children: [
          for (var i = 0; i < chips.energy; i++)
            _Chip(label: '1', size: size, energy: true),
          for (var i = 0; i < chips.essence; i++)
            _Chip(label: '✦', size: size, energy: false),
          SizedBox(width: m.width * 0.01),
          Text('Réserve runique'.toUpperCase(), style: m.zoneLabel(null)),
        ],
      ),
    );
  }

  Widget _focus(BuildContext context, _BoardMetrics m) {
    final focus = scene.focus!;
    final height = m.height * 0.76;
    final width = height / _cardRatio;
    return Positioned(
      left: m.x(50) - width / 2,
      top: m.y(43) - height / 2,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => showGuideCardZoom(context, focus.card),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _BoardImage(
                url: focus.card.image,
                name: focus.card.name,
                radius: width * 0.045,
                elevated: true,
              ),
            ),
            for (final note in focus.notes)
              Positioned(
                left: width * note.x / 100 - m.noteSize / 2,
                top: height * note.y / 100 - m.noteSize / 2,
                child: Container(
                  width: m.noteSize,
                  height: m.noteSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: RiftColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    note.number,
                    style: TextStyle(
                      fontFamily: RiftFonts.mono,
                      fontWeight: FontWeight.w600,
                      fontSize: m.noteSize * 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const double _cardRatio = 1039 / 744;
const double _wideRatio = 744 / 1038;

/// Conversion pourcentage → pixels et petites tailles dérivées.
class _BoardMetrics {
  const _BoardMetrics(this.width, this.height);

  final double width;
  final double height;

  double x(double percent) => percent / 100 * width;

  double y(double percent) => percent / 100 * height;

  double get labelSize => (width * 0.024).clamp(6.5, 11.0);

  double get noteSize => (width * 0.055).clamp(14.0, 26.0);

  TextStyle zoneLabel(Color? tint) => TextStyle(
    fontFamily: RiftFonts.mono,
    fontSize: labelSize,
    letterSpacing: 0.8,
    height: 1.2,
    color: tint ?? RiftColors.goldSoft.withValues(alpha: 0.75),
  );
}

/// Visuel d'une carte posée : coins arrondis, halo hex quand elle est
/// désignée, transparence pour une carte « fantôme ».
class _BoardImage extends StatelessWidget {
  const _BoardImage({
    required this.url,
    required this.name,
    required this.radius,
    this.glow = false,
    this.ghost = false,
    this.elevated = false,
  });

  final String url;
  final String name;
  final double radius;
  final bool glow;
  final bool ghost;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget image = ClipRRect(
      borderRadius: borderRadius,
      child: url.isEmpty
          ? ColoredBox(
              color: RiftColors.darkPaper2,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: RiftFonts.mono,
                      fontSize: 7,
                      color: RiftColors.goldSoft,
                    ),
                  ),
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: url,
              cacheManager: riftImageCache,
              fit: BoxFit.cover,
              fadeInDuration: RiftMotion.base,
              placeholder: (context, _) =>
                  const ColoredBox(color: RiftColors.darkPaper2),
              errorWidget: (context, _, _) =>
                  const ColoredBox(color: RiftColors.darkPaper2),
            ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          if (glow)
            BoxShadow(
              color: RiftColors.hex.withValues(alpha: 0.65),
              blurRadius: 10,
              spreadRadius: 2,
            )
          else if (elevated)
            BoxShadow(
              color: RiftColors.inkStrong.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Opacity(opacity: ghost ? 0.55 : 1, child: image),
    );
  }
}

/// Dos de carte : bleu nuit, filet or, rondelle centrale.
class _CardBack extends StatelessWidget {
  const _CardBack({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ring = constraints.maxWidth * 0.34;
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF12263F), RiftColors.inkStrong],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: RiftColors.gold.withValues(alpha: 0.8),
              width: 1.2,
            ),
          ),
          child: Center(
            child: Container(
              width: ring,
              height: ring,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: RiftColors.goldSoft.withValues(alpha: 0.8),
                  width: 1.2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Étiquette d'état d'un champ de bataille (« Contesté », « À vous »).
class _Flag extends StatelessWidget {
  const _Flag({required this.label, required this.color, required this.m});

  final String label;
  final Color color;
  final _BoardMetrics m;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: m.width * 0.014,
        vertical: m.width * 0.004,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(RiftRadius.full),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: RiftFonts.mono,
          fontSize: m.labelSize,
          letterSpacing: 0.8,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Pastille de puissance (ronde) ou de dégâts.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.m,
    this.circle = false,
  });

  final String label;
  final Color color;
  final _BoardMetrics m;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final size = (m.width * 0.042).clamp(13.0, 26.0);
    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      alignment: Alignment.center,
      padding: circle
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: size * 0.22),
      decoration: BoxDecoration(
        color: color,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(RiftRadius.full),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: circle ? RiftFonts.display : RiftFonts.mono,
          fontSize: size * 0.58,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Jeton de la réserve runique : énergie (or) ou essence (chaos).
class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.size, required this.energy});

  final String label;
  final double size;
  final bool energy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.only(right: size * 0.18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: energy ? RiftColors.goldSoft : RiftColors.chaos,
        border: Border.all(
          color: energy ? RiftColors.goldDeep : Colors.white,
          width: 1.2,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: RiftFonts.mono,
          fontSize: size * 0.5,
          color: energy ? RiftColors.inkStrong : Colors.white,
        ),
      ),
    );
  }
}

/// Flèche courbe (pioche, déplacement) : même cubique que le site, tracée en
/// pointillés hex avec un halo et une pointe.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.arrow, required this.metrics});

  final SceneArrow arrow;
  final _BoardMetrics metrics;

  @override
  void paint(Canvas canvas, Size size) {
    final from = Offset(metrics.x(arrow.from.x), metrics.y(arrow.from.y));
    final to = Offset(metrics.x(arrow.to.x), metrics.y(arrow.to.y));
    final midY = (from.dy + to.dy) / 2;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);

    final stroke = math.max(size.width * 0.007, 1.4);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 2.6
        ..strokeCap = StrokeCap.round
        ..color = RiftColors.hex.withValues(alpha: 0.28),
    );

    final dashed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = RiftColors.hex;
    final dash = size.width * 0.02;
    final gap = dash * 0.75;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), dashed);
        distance = end + gap;
      }
      // Pointe orientée selon la tangente finale.
      final tangent = metric.getTangentForOffset(metric.length);
      if (tangent == null) continue;
      final vector = tangent.vector;
      final angle = math.atan2(vector.dy, vector.dx);
      final head = stroke * 3;
      final tip = tangent.position;
      final left = tip + Offset.fromDirection(angle + 2.6, head);
      final right = tip + Offset.fromDirection(angle - 2.6, head);
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo(left.dx, left.dy)
          ..lineTo(right.dx, right.dy)
          ..close(),
        Paint()..color = RiftColors.hex,
      );
    }
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      !identical(oldDelegate.arrow, arrow) ||
      oldDelegate.metrics.width != metrics.width ||
      oldDelegate.metrics.height != metrics.height;
}
