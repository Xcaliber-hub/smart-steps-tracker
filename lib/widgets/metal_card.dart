// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Metal presets for [MetalCard]; each ships dark and light tunings.
enum MetalPreset { chromatic, silver, gold }

/// A [Card] wrapped in a liquid-metal finish.
///
/// Drawn over the card, all in plain Flutter (no shaders):
///  * a chrome rim whose bright bands flow around the border,
///  * a soft glow hugging the rim,
///  * a wandering halo and a slow diagonal sheen inside the card,
///  * optionally a light edge on the top inside of the rim ([innerShadow]).
///
/// Uses the theme's card margin and shape, so it is a drop-in replacement for
/// [Card]. Pauses when [paused] is true or when the system's "remove
/// animations" setting is on.
class MetalCard extends StatefulWidget {
  const MetalCard({
    super.key,
    required this.child,
    this.preset = MetalPreset.chromatic,
    this.strength = 1.0,
    this.innerShadow = true,
    this.disableGlow = false,
    this.paused = false,
    this.borderRadius = 24,
    this.margin,
    this.clipBehavior = Clip.none,
    this.duration = const Duration(seconds: 12),
  });

  /// Card content.
  final Widget child;

  /// Metal flavour.
  final MetalPreset preset;

  /// 0 to 1; multiplies the opacity of every layer of the effect.
  final double strength;

  /// Light rim on the top inside edge of the border.
  final bool innerShadow;

  /// Removes the soft glow around the rim.
  final bool disableGlow;

  /// Freezes the animation.
  final bool paused;

  /// Corner radius; match the card theme's radius.
  final double borderRadius;

  /// Outer margin; defaults to the theme's card margin.
  final EdgeInsetsGeometry? margin;

  /// Passed to the inner [Card]; use [Clip.antiAlias] for ink ripples.
  final Clip clipBehavior;

  /// Time for the metal to complete one loop.
  final Duration duration;

  @override
  State<MetalCard> createState() => _MetalCardState();
}

class _MetalCardState extends State<MetalCard>
    with SingleTickerProviderStateMixin {
  // Random start so neighbouring cards do not shimmer in lockstep.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: math.Random().nextDouble(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant MetalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    _syncAnimation();
  }

  void _syncAnimation() {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldRun = !widget.paused && !reduceMotion;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final strength = widget.strength.clamp(0.0, 1.0).toDouble();
    final tuning = _Tuning.of(widget.preset, dark);
    final margin = widget.margin ??
        theme.cardTheme.margin ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return Padding(
      padding: margin,
      child: RepaintBoundary(
        child: CustomPaint(
          foregroundPainter: _MetalPainter(
            progress: _controller,
            radius: widget.borderRadius,
            rimColors: [
              for (final c in tuning.rim) c.withValues(alpha: c.a * strength),
            ],
            highlight: tuning.highlight,
            strength: strength,
            innerShadow: widget.innerShadow,
            glow: !widget.disableGlow,
            dark: dark,
          ),
          child: Card(
            margin: EdgeInsets.zero,
            clipBehavior: widget.clipBehavior,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Colours of one preset: nine rim colours (first equals last, so the sweep
/// wraps seamlessly) plus the tint used for the halo and sheen.
class _Tuning {
  const _Tuning({required this.rim, required this.highlight});

  final List<Color> rim;
  final Color highlight;

  static const List<Color> _chromatic = [
    Color(0x4DFFFFFF),
    Color(0xFF8EA2FF),
    Color(0xFFEBDCFF),
    Color(0x4DFFFFFF),
    Color(0xFFFFB3DE),
    Color(0xFFFFF1C2),
    Color(0x4DFFFFFF),
    Color(0xFF7DE3FF),
    Color(0x4DFFFFFF),
  ];

  static const List<Color> _silver = [
    Color(0x40FFFFFF),
    Color(0xFFD7DBE6),
    Color(0xFFFFFFFF),
    Color(0x40FFFFFF),
    Color(0xFFAEB4C2),
    Color(0xFFF2F4F8),
    Color(0x40FFFFFF),
    Color(0xFF9AA1B0),
    Color(0x40FFFFFF),
  ];

  static const List<Color> _gold = [
    Color(0x40FFE08A),
    Color(0xFFE6B84C),
    Color(0xFFFFF0B8),
    Color(0x40C8962E),
    Color(0xFFD9A441),
    Color(0xFFFFE9A8),
    Color(0x40FFE08A),
    Color(0xFFB8862B),
    Color(0x40FFE08A),
  ];

  static Color _darken(Color c, double amount) {
    final base = Color.lerp(
      c.withValues(alpha: 1),
      const Color(0xFF202028),
      amount,
    )!;
    return base.withValues(alpha: c.a);
  }

  static _Tuning of(MetalPreset preset, bool dark) {
    final List<Color> rim;
    final Color highlight;
    switch (preset) {
      case MetalPreset.chromatic:
        rim = _chromatic;
        highlight = const Color(0xFFC9B8FF);
      case MetalPreset.silver:
        rim = _silver;
        highlight = const Color(0xFFE8EAF2);
      case MetalPreset.gold:
        rim = _gold;
        highlight = const Color(0xFFFFD98A);
    }
    if (dark) return _Tuning(rim: rim, highlight: highlight);
    // Light tuning: deeper metals that still read on a pale surface.
    return _Tuning(
      rim: [for (final c in rim) _darken(c, 0.45)],
      highlight: _darken(highlight, 0.3),
    );
  }
}

class _MetalPainter extends CustomPainter {
  _MetalPainter({
    required this.progress,
    required this.radius,
    required this.rimColors,
    required this.highlight,
    required this.strength,
    required this.innerShadow,
    required this.glow,
    required this.dark,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final double radius;
  final List<Color> rimColors;
  final Color highlight;
  final double strength;
  final bool innerShadow;
  final bool glow;
  final bool dark;

  static const List<double> _stops = [
    0,
    0.125,
    0.25,
    0.375,
    0.5,
    0.625,
    0.75,
    0.875,
    1,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0 || size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final angle = progress.value * 2 * math.pi;

    // Interior: wandering halo and travelling sheen, clipped to the card.
    canvas.save();
    canvas.clipRRect(rrect);
    _paintHalo(canvas, size, angle);
    _paintSheen(canvas, size);
    canvas.restore();

    // Soft glow hugging the rim.
    if (glow) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..shader = _rimShader(rect, angle, 0.35);
      canvas.drawRRect(rrect, glowPaint);
    }

    // Chrome rim.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = _rimShader(rect, angle, 1);
    canvas.drawRRect(rrect.deflate(0.8), rim);

    // Light edge on the top inside of the rim.
    if (innerShadow) {
      final top = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height * 0.5),
          [
            Colors.white.withValues(alpha: (dark ? 0.38 : 0.7) * strength),
            Colors.white.withValues(alpha: 0),
          ],
        );
      canvas.drawRRect(rrect.deflate(2.2), top);
    }
  }

  ui.Shader _rimShader(Rect rect, double angle, double factor) {
    final colors = factor == 1
        ? rimColors
        : [for (final c in rimColors) c.withValues(alpha: c.a * factor)];
    return SweepGradient(
      colors: colors,
      stops: _stops,
      transform: GradientRotation(angle),
    ).createShader(rect);
  }

  /// A soft pool of light that drifts around the card on a figure-eight.
  void _paintHalo(Canvas canvas, Size size, double angle) {
    final center = Offset(
      size.width * (0.5 + 0.38 * math.cos(angle)),
      size.height * (0.5 + 0.38 * math.sin(angle * 2)),
    );
    final alpha = (dark ? 0.16 : 0.10) * strength;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        size.shortestSide * 0.9,
        [highlight.withValues(alpha: alpha), highlight.withValues(alpha: 0)],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  /// A faint diagonal band of light that sweeps across once per loop.
  void _paintSheen(Canvas canvas, Size size) {
    final band = size.shortestSide * 0.55;
    final x = -size.height + progress.value * (size.width + size.height * 2);
    final tint = dark ? Colors.white : highlight;
    final alpha = (dark ? 0.08 : 0.10) * strength;
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x, 0),
        Offset(x + band, band * 0.6),
        [
          tint.withValues(alpha: 0),
          tint.withValues(alpha: alpha),
          tint.withValues(alpha: 0),
        ],
        const [0, 0.5, 1],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_MetalPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.radius != radius ||
      oldDelegate.rimColors != rimColors ||
      oldDelegate.highlight != highlight ||
      oldDelegate.strength != strength ||
      oldDelegate.innerShadow != innerShadow ||
      oldDelegate.glow != glow ||
      oldDelegate.dark != dark;
}
