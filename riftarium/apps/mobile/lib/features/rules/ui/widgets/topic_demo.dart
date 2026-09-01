import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/guides.dart';

/// Mini-scène d'une mécanique : quelques images commentées, avancées à la
/// main (points sous la scène ou glissement). Même langage visuel que le
/// plateau du guide : fond d'encre, zones en pointillés, cartes en parchemin.
class TopicDemoView extends StatefulWidget {
  const TopicDemoView({super.key, required this.demo});

  final TopicDemo demo;

  @override
  State<TopicDemoView> createState() => _TopicDemoViewState();
}

class _TopicDemoViewState extends State<TopicDemoView> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.demo.frames.length) return;
    _controller.animateToPage(
      index,
      duration: RiftMotion.base,
      curve: RiftMotion.ease,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final frames = widget.demo.frames;
    if (frames.isEmpty) return const SizedBox.shrink();
    final frame = frames[_index.clamp(0, frames.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(RiftRadius.md),
          // Sur téléphone, la scène est plus haute (4/3) que sur le site
          // (16/7) : les cartes gardent une taille lisible et tiennent dans
          // les zones exprimées en pourcentage.
          child: AspectRatio(
            aspectRatio: MediaQuery.sizeOf(context).width < 600
                ? 4 / 3
                : 16 / 7,
            child: PageView.builder(
              controller: _controller,
              itemCount: frames.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => _DemoStage(frame: frames[index]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: Text(frame.caption, style: text.small)),
            const SizedBox(width: 10),
            for (var i = 0; i < frames.length; i++)
              Semantics(
                button: true,
                label: 'Image ${i + 1}',
                child: GestureDetector(
                  onTap: () => _goTo(i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnimatedContainer(
                      duration: RiftMotion.quick,
                      width: i == _index ? 18 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? RiftColors.gold
                            : RiftColors.gold.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(RiftRadius.full),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DemoStage extends StatelessWidget {
  const _DemoStage({required this.frame});

  final DemoFrame frame;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : width * 3 / 4;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF12253C), RiftColors.night],
            ),
          ),
          child: Stack(
            children: [
              for (final item in frame.items) _positioned(item, width, height),
            ],
          ),
        );
      },
    );
  }

  Widget _positioned(DemoItem item, double width, double height) {
    final child = _DemoItemView(item: item, stageWidth: width);
    if (item.type == DemoItemType.zone) {
      final zoneWidth = width * 0.26;
      final zoneHeight = height * 0.52;
      return Positioned(
        left: width * item.x / 100 - zoneWidth / 2,
        top: height * item.y / 100 - zoneHeight / 2,
        width: zoneWidth,
        height: zoneHeight,
        child: child,
      );
    }
    // Les autres éléments se dimensionnent d'eux-mêmes : on les aligne sur
    // leur point d'ancrage dans toute la scène. `Align` les garde dans le
    // cadre : un libellé large collé au bord droit (« Arrière-ligne », à
    // x = 86) n'aurait sinon que quelques pixels et se replierait sur
    // trois lignes.
    return Positioned.fill(
      child: Align(
        alignment: Alignment(item.x / 50 - 1, item.y / 50 - 1),
        child: child,
      ),
    );
  }
}

class _DemoItemView extends StatelessWidget {
  const _DemoItemView({required this.item, required this.stageWidth});

  final DemoItem item;
  final double stageWidth;

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(
      fontFamily: RiftFonts.mono,
      fontSize: (stageWidth * 0.022).clamp(7.0, 11.0),
      letterSpacing: 0.8,
      height: 1.25,
      color: RiftColors.goldSoft.withValues(alpha: 0.8),
    );
    final content = switch (item.type) {
      DemoItemType.zone => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: item.hot
                ? RiftColors.fury
                : RiftColors.goldSoft.withValues(alpha: 0.6),
          ),
          borderRadius: BorderRadius.circular(RiftRadius.sm),
        ),
        // Libellé en haut de la zone : le bas est occupé par les cartes.
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(item.label.toUpperCase(), style: label),
          ),
        ),
      ),
      DemoItemType.unit => _unit(),
      DemoItemType.card => _card(),
      DemoItemType.chip => _chip(),
      DemoItemType.label || DemoItemType.unknown => _label(),
    };
    return Opacity(opacity: item.dead ? 0.3 : 1, child: content);
  }

  Widget _unit() {
    final size = (stageWidth * 0.075).clamp(22.0, 46.0);
    return Transform.rotate(
      angle: item.tapped ? 1.5708 : 0,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: item.isFoe ? RiftColors.fury : RiftColors.hex,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: item.glow
              ? [
                  BoxShadow(
                    color: RiftColors.hex.withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          item.value,
          style: TextStyle(
            fontFamily: RiftFonts.display,
            fontSize: size * 0.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _card() {
    final width = (stageWidth * 0.13).clamp(40.0, 60.0);
    return Transform.rotate(
      angle: item.tapped ? 1.5708 : 0,
      child: Container(
        width: width,
        height: width * 64 / 46,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFAF2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: item.isFoe ? RiftColors.fury : RiftColors.gold,
            width: 1.5,
          ),
          boxShadow: item.glow
              ? [
                  BoxShadow(
                    color: RiftColors.hex.withValues(alpha: 0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          item.label,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: RiftFonts.mono,
            fontSize: (stageWidth * 0.024).clamp(7.5, 11.0),
            height: 1.25,
            color: RiftColors.night,
          ),
        ),
      ),
    );
  }

  Widget _chip() {
    final height = (stageWidth * 0.05).clamp(18.0, 28.0);
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: height * 0.35),
      decoration: BoxDecoration(
        color: item.ok ? RiftColors.hex : RiftColors.fury,
        borderRadius: BorderRadius.circular(RiftRadius.full),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        item.value,
        style: TextStyle(
          fontFamily: RiftFonts.mono,
          fontSize: height * 0.44,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _label() {
    final size = (stageWidth * 0.022).clamp(7.0, 11.0);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size * 0.9,
        vertical: size * 0.3,
      ),
      decoration: BoxDecoration(
        color: item.glow
            ? RiftColors.gold
            : RiftColors.goldSoft.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(RiftRadius.full),
        border: Border.all(color: RiftColors.goldSoft.withValues(alpha: 0.6)),
      ),
      child: Text(
        item.label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: RiftFonts.mono,
          fontSize: size,
          letterSpacing: 0.8,
          color: item.glow ? Colors.white : RiftColors.goldSoft,
        ),
      ),
    );
  }
}
