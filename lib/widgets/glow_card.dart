// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A [Card] with light spilling out from behind it.
///
/// A soft halo bleeds out around the edges and a flattened pool of light lands
/// on the surface just below the card, like a lit panel above a dark floor.
/// Uses the theme's card margin and shape, so it is a drop-in replacement for
/// [Card]. Leave a little vertical space below it for the spill.
class GlowCard extends StatelessWidget {
  const GlowCard({
    super.key,
    required this.child,
    this.color,
    this.intensity = 1.0,
    this.borderRadius = 24,
    this.margin,
  });

  /// Card content.
  final Widget child;

  /// Light colour; defaults to the theme's primary (accent) colour.
  final Color? color;

  /// 0 to 1; scales the brightness of the glow.
  final double intensity;

  /// Corner radius; match the card theme's radius.
  final double borderRadius;

  /// Outer margin; defaults to the theme's card margin.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedMargin = margin ??
        theme.cardTheme.margin ??
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8);

    return Padding(
      padding: resolvedMargin,
      child: CustomPaint(
        painter: _GlowPainter(
          color: color ?? theme.colorScheme.primary,
          intensity: intensity.clamp(0.0, 1.0).toDouble(),
          radius: borderRadius,
          dark: theme.brightness == Brightness.dark,
        ),
        child: Card(margin: EdgeInsets.zero, child: child),
      ),
    );
  }
}

/// Paints behind the card; the card itself covers the middle of the halo.
class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.color,
    required this.intensity,
    required this.radius,
    required this.dark,
  });

  final Color color;
  final double intensity;
  final double radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0 || size.isEmpty) return;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    // Halo bleeding out around the card, weighted slightly downwards.
    canvas.drawRRect(
      rrect.inflate(2).shift(const Offset(0, 6)),
      Paint()
        ..color = color.withValues(alpha: (dark ? 0.34 : 0.22) * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Pool of light on the "floor" just below the bottom edge: a circular
    // radial gradient squashed into a wide, flat ellipse.
    final spill = Color.lerp(color, Colors.white, dark ? 0.35 : 0.1)!;
    final reach = size.width * 0.46;
    canvas.save();
    canvas.translate(size.width / 2, size.height + 2);
    canvas.scale(1, 0.26);
    canvas.drawCircle(
      Offset.zero,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          reach,
          [
            spill.withValues(alpha: 0.55 * intensity),
            spill.withValues(alpha: 0.20 * intensity),
            spill.withValues(alpha: 0),
          ],
          const [0, 0.55, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.intensity != intensity ||
      oldDelegate.radius != radius ||
      oldDelegate.dark != dark;
}
