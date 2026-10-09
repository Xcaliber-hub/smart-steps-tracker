// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../utils/formatters.dart';
import '../viewmodels/providers.dart';

/// First-run onboarding: welcome, daily goal, and optional profile details.
class OnboardingScreen extends ConsumerStatefulWidget {
  /// Creates the onboarding flow.
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  double _goal = 10000;
  UnitSystem _units = UnitSystem.metric;
  Gender? _gender;

  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    final current = ref.read(profileProvider);
    final updated = current.copyWith(
      dailyGoal: _goal.round(),
      unitSystem: _units,
      age: int.tryParse(_ageController.text.trim()),
      heightCm: double.tryParse(_heightController.text.trim()),
      weightKg: double.tryParse(_weightController.text.trim()),
      gender: _gender,
    );
    await ref.read(profileProvider.notifier).update(updated);
    await ref.read(settingsRepositoryProvider).setOnboardingDone();
    HapticFeedback.mediumImpact();
    ref.invalidate(onboardingDoneProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  _welcomePage(context, colorScheme),
                  _goalPage(context, colorScheme),
                  _profilePage(context, colorScheme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _page == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == i
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomePage(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.directions_walk,
            size: 96,
            color: colorScheme.primary,
            semanticLabel: 'Walking person',
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to\nStride',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'A free and open-source step counter. '
            'No accounts, no ads, no tracking — just your steps.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Card(
            color: colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: colorScheme.onSecondaryContainer,
                    semanticLabel: 'Privacy',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'To count your steps, the app uses your device\u2019s '
                      'activity-recognition sensor. You\u2019ll be asked for '
                      'permission next — your step data never leaves this '
                      'device.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => _goTo(1),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text('Get started'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalPage(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.flag_outlined,
            size: 72,
            color: colorScheme.primary,
            semanticLabel: 'Goal flag',
          ),
          const SizedBox(height: 24),
          Text(
            'Set your daily goal',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'You can change this any time in Settings.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          Text(
            Formatters.steps(_goal.round()),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          Text(
            'steps per day',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Daily step goal',
            value: '${_goal.round()} steps',
            child: Slider(
              value: _goal,
              min: 1000,
              max: 30000,
              divisions: 58,
              label: Formatters.steps(_goal.round()),
              onChanged: (value) => setState(() => _goal = value),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Unit system',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Unit system',
            child: SegmentedButton<UnitSystem>(
              segments: const [
                ButtonSegment(
                  value: UnitSystem.metric,
                  label: Text('Metric'),
                ),
                ButtonSegment(
                  value: UnitSystem.imperial,
                  label: Text('Imperial'),
                ),
              ],
              selected: {_units},
              onSelectionChanged: (selected) =>
                  setState(() => _units = selected.first),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => _goTo(0),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: () => _goTo(2),
                child: const Text('Continue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profilePage(BuildContext context, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.person_outline,
            size: 72,
            color: colorScheme.primary,
            semanticLabel: 'Person',
          ),
          const SizedBox(height: 24),
          Text(
            'About you',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Optional — used only for calorie and distance estimates, '
            'and stored on-device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Age',
              suffixText: 'years',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _heightController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Height',
              suffixText: 'cm',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Weight',
              suffixText: 'kg',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Gender?>(
            initialValue: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<Gender?>(
                value: null,
                child: Text('Prefer not to say'),
              ),
              for (final g in Gender.values)
                DropdownMenuItem<Gender?>(
                  value: g,
                  child: Text(
                    g.name[0].toUpperCase() + g.name.substring(1),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => _goTo(1),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: _finish,
                child: const Text('Start tracking'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
