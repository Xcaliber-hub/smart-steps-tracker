// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';

/// A small tappable card showing one headline metric.
///
/// Shows [icon] in a tonal circle next to [value] (large) and [label]
/// (caption). When [onTap] is provided the whole card ripples and is
/// exposed to assistive tech as a button.
class StatCard extends StatelessWidget {
  /// Creates a stat card with [label], [value] and [icon].
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });

  /// Caption describing the metric, e.g. "Distance".
  final String label;

  /// Formatted metric value, e.g. "5.2 km".
  final String value;

  /// Icon shown in the tonal circle.
  final IconData icon;

  /// Called when the card is tapped; null makes the card non-interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return MergeSemantics(
      child: Semantics(
        label: '$label: $value',
        button: onTap != null,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? content
              : InkWell(
                  onTap: onTap,
                  child: content,
                ),
        ),
      ),
    );
  }
}
