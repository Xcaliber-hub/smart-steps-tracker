// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';

/// Section heading row: bold [title] with an optional trailing [action].
///
/// Used to label content sections (charts, lists) on the screens.
class SectionHeader extends StatelessWidget {
  /// Creates a section header with [title] and an optional [action].
  const SectionHeader({super.key, required this.title, this.action});

  /// Section title text.
  final String title;

  /// Trailing widget, e.g. a "See all" TextButton.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}
