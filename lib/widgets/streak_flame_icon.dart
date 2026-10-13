// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';

/// Flame icon that gives a short bounce when a loaded streak increases.
class StreakFlameIcon extends StatefulWidget {
  const StreakFlameIcon({
    super.key,
    required this.streak,
    this.dataReady = true,
    this.size = 24,
  });

  final int streak;
  final bool dataReady;
  final double size;

  @override
  State<StreakFlameIcon> createState() => _StreakFlameIconState();
}

class _StreakFlameIconState extends State<StreakFlameIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.42,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 32,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.42,
        end: 0.94,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 28,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.94,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
  ]).animate(_controller);

  late final Animation<double> _sway = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 0, end: -0.035), weight: 25),
    TweenSequenceItem(
      tween: Tween<double>(begin: -0.035, end: 0.035),
      weight: 50,
    ),
    TweenSequenceItem(tween: Tween<double>(begin: 0.035, end: 0), weight: 25),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant StreakFlameIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dataReady &&
        widget.dataReady &&
        widget.streak > oldWidget.streak) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSecondaryContainer;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: _sway.value * 6.283185307179586,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: Icon(Icons.local_fire_department, size: widget.size, color: color),
    );
  }
}
