// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Colour presets for [BeamBorder].
enum BeamPalette { colorful, mono, ocean, sunset }

/// Rides an animated glow around the border of [child].
///
/// A comet-like beam (bright head, fading tail) travels at constant speed
/// along a rounded-rectangle outline drawn over the child. Pauses when
/// [active] is false or when the system's "remove animations" setting is on.
class BeamBorder extends StatefulWidget {
  const BeamBorder({
    super.key,
    required this.child,
    required this.borderRadius,
    this.palette = BeamPalette.colorful,
    this.strength = 0.7,
    this.active = true,
    this.duration = const Duration(seconds: 5),
  });

  /// The widget the beam travels around.
  final Widget child;

  /// Corner radius of the outline; match the child's own radius.
  final double borderRadius;

  /// Colour preset.
  final BeamPalette palette;

  /// Glow intensity from 0 to 1.
  final double strength;

  /// Pauses the animation when false.
  final bool active;

  /// Time for the beam to complete one lap.
  final Duration duration;

  @override
  State<BeamBorder> createState() => _BeamBorderState();
}

class _BeamBorderState extends State<BeamBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant BeamBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldRun = widget.active && !reduceMotion;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Color> _colors(Color monoColor) {
    switch (widget.palette) {
      case BeamPalette.colorful:
        return const [
          Color(0xFF38BDF8),
          Color(0xFFA78BFA),
          Color(0xFFF472B6),
          Color(0xFFFBBF24),
        ];
      case BeamPalette.mono:
        return [monoColor, monoColor];
      case BeamPalette.ocean:
        return const [
          Color(0xFF22D3EE),
          Color(0xFF3B82F6),
          Color(0xFF6366F1),
        ];
      case BeamPalette.sunset:
        return const [
          Color(0xFFFB923C),
          Color(0xFFF43F5E),
          Color(0xFFA855F7),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _BeamPainter(
          progress: _controller,
          radius: widget.borderRadius,
          colors: _colors(onSurface),
          strength: widget.strength.clamp(0.0, 1.0).toDouble(),
        ),
        child: widget.child,
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter({
    required this.progress,
    required this.radius,
    required this.colors,
    required this.strength,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final double radius;
  final List<Color> colors;
  final double strength;

  /// The beam is drawn as many short, increasingly opaque strokes.
  static const int _segments = 28;

  /// Fraction of the full outline covered by the beam.
  static const double _beamFraction = 0.3;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 || size.isEmpty) return;

    final rect = (Offset.zero & size).deflate(1);
    final outline = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final metrics = outline.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final total = metric.length;
    final beamLength = total * _beamFraction;
    final segmentLength = beamLength / _segments;
    final head = progress.value * total;

    final core = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    for (var i = 0; i < _segments; i++) {
      final t = (i + 1) / _segments; // 0 = tail, 1 = head
      final start = head - beamLength + i * segmentLength;
      // Slight overlap so neighbouring segments leave no visible gaps.
      final path = _segment(metric, start, start + segmentLength * 1.15);
      final alpha = math.pow(t, 1.8).toDouble() * strength;
      final color = _sample(t);
      glow.color = color.withValues(alpha: alpha * 0.55);
      core.color = color.withValues(alpha: alpha);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, core);
    }
  }

  /// Extracts the part of [metric] between [start] and [end], wrapping past
  /// the end of the outline back to its beginning.
  Path _segment(PathMetric metric, double start, double end) {
    final total = metric.length;
    var from = start % total;
    if (from < 0) from += total;
    final to = from + (end - start);
    if (to <= total) return metric.extractPath(from, to);
    final first = metric.extractPath(from, total);
    final second = metric.extractPath(0, to - total);
    return first..addPath(second, Offset.zero);
  }

  Color _sample(double t) {
    if (colors.length == 1) return colors.first;
    final scaled = t * (colors.length - 1);
    final index = scaled.floor().clamp(0, colors.length - 2).toInt();
    return Color.lerp(colors[index], colors[index + 1], scaled - index)!;
  }

  @override
  bool shouldRepaint(_BeamPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.radius != radius ||
      oldDelegate.strength != strength ||
      oldDelegate.colors != colors;
}
