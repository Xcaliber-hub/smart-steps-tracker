// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/day_record.dart';
import '../services/firebase_service.dart';
import '../services/group_service.dart';
import '../viewmodels/providers.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(stepSharingSyncProvider);
    final firebase = ref.watch(firebaseAvailableProvider);
    return firebase.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _FirebaseUnavailable(),
      data: (available) {
        if (!available) return const _FirebaseUnavailable();
        final auth = ref.watch(authStateProvider);
        return auth.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorPanel(message: 'Account error: $error'),
          data: (user) => user == null
              ? const _AuthenticationPanel()
              : _SignedInGroups(user: user),
        );
      },
    );
  }
}

class _FirebaseUnavailable extends StatelessWidget {
  const _FirebaseUnavailable();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
      children: [
        Text('Friends & groups', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_outlined, size: 34, color: colors.primary),
                const SizedBox(height: 12),
                Text('Firebase setup needed', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Your step tracker is still working locally. To enable sign-in and private groups, set up a Firebase project, enable Email/Password Authentication and Cloud Firestore, then provide the Android Firebase options described in README.md.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'No account or cloud data is created until you configure Firebase. Age, height, weight, gender, step history, distance and calories are not sent to Firebase.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthenticationPanel extends StatefulWidget {
  const _AuthenticationPanel();

  @override
  State<_AuthenticationPanel> createState() => _AuthenticationPanelState();
}

class _AuthenticationPanelState extends State<_AuthenticationPanel> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  String _authError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already uses that email. Sign in instead.';
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Choose a stronger password (at least 6 characters).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password was not recognized.';
        case 'network-request-failed':
          return 'Could not reach Firebase. Check your connection and try again.';
      }
    }
    return 'Could not ${_registering ? 'create the account' : 'sign in'}: $error';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    if (_registering && _password.text.length < 6) {
      setState(() => _error = 'Choose a password with at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = AuthService();
      if (_registering) {
        await service.register(
          email: _email.text,
          password: _password.text,
          displayName: _displayName.text,
        );
      } else {
        await service.signIn(email: _email.text, password: _password.text);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _authError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
      children: [
        Text('Friends & groups', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.groups_2_outlined, size: 38, color: colors.primary),
                const SizedBox(height: 10),
                Text(
                  _registering ? 'Create your Stride account' : 'Sign in to Stride',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use an account to create private groups or join friends. Your local step history remains on this device.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_registering) ...[
                  TextField(
                    controller: _displayName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Display name (optional)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) {
                    if (!_busy) _submit();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: colors.error)),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_registering ? 'Create account' : 'Sign in'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _registering = !_registering;
                            _error = null;
                          }),
                  child: Text(
                    _registering
                        ? 'Already have an account? Sign in'
                        : 'New to Stride? Create an account',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Group members only see the display name you choose and, only after you opt in, today’s step total and last-updated time.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _SignedInGroups extends ConsumerWidget {
  const _SignedInGroups({required this.user});

  final User user;

  String get _displayName {
    final name = user.displayName?.trim() ?? '';
    return name.isEmpty ? 'Stride member' : name;
  }

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Group name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !context.mounted) return;
    try {
      final group = await ref.read(groupServiceProvider).createGroup(
            uid: user.uid,
            displayName: _displayName,
            name: name,
          );
      ref.invalidate(myGroupsProvider(user.uid));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created ${group.name}. Invite friends to join.')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, 'Could not create the group: $error');
    }
  }

  Future<void> _joinGroup(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join a group'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 22,
          decoration: const InputDecoration(
            labelText: 'Invite code',
            helperText: 'Ask a group member for their private code.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Join')),
        ],
      ),
    );
    controller.dispose();
    if (code == null || !context.mounted) return;
    try {
      final group = await ref.read(groupServiceProvider).joinByInvite(
            uid: user.uid,
            displayName: _displayName,
            code: code,
          );
      ref.invalidate(myGroupsProvider(user.uid));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You joined ${group.name}.')),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, 'Could not join the group: $error');
    }
  }

  Future<void> _setSharing(BuildContext context, WidgetRef ref, bool enabled) async {
    if (enabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share today’s steps?'),
          content: const Text(
            'Members of your private groups will be able to see only your step total for today and when it was last updated. Your age, height, weight, gender, step history, distance, calories and daily goal are not shared.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Share today’s steps')),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }
    try {
      final service = ref.read(groupServiceProvider);
      await service.setSharingEnabled(user.uid, enabled);
      ref.invalidate(sharingOptInProvider(user.uid));
      if (enabled) {
        final record = ref.read(todayRecordProvider).valueOrNull;
        if (record != null) {
          await service.publishTodaySteps(uid: user.uid, record: record);
        }
      }
    } catch (error) {
      if (!enabled) ref.invalidate(sharingOptInProvider(user.uid));
      if (context.mounted) _showError(context, 'Could not update step sharing: $error');
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(groupServiceProvider).setSharingEnabled(user.uid, false);
    } catch (error) {
      ref.invalidate(sharingOptInProvider(user.uid));
      if (context.mounted) {
        _showError(
          context,
          'Sharing is off on this device, but the cloud total could not be removed. Reconnect and try signing out again. ($error)',
        );
      }
      return;
    }
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (error) {
      if (context.mounted) _showError(context, 'Could not sign out: $error');
    }
  }

  Future<void> _createInvite(
    BuildContext context,
    WidgetRef ref,
    GroupSummary group,
  ) async {
    try {
      final code = await ref.read(groupServiceProvider).createInvite(
            groupId: group.id,
            creatorUid: user.uid,
          );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Invite to ${group.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share this private code with the friend you want to invite. It expires in 7 days.'),
              const SizedBox(height: 16),
              SelectableText(
                code,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied.')),
                );
              },
              child: const Text('Copy code'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _showError(context, 'Could not create an invite: $error');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider(user.uid));
    final sharing = ref.watch(sharingOptInProvider(user.uid));
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 112 + MediaQuery.of(context).padding.bottom),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Friends & groups', style: Theme.of(context).textTheme.headlineMedium),
                  Text(
                    user.email ?? user.displayName ?? 'Signed in',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => _signOut(context, ref),
              icon: const Icon(Icons.logout_outlined),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              sharing.when(
                loading: () => const ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Step sharing'),
                  subtitle: Text('Loading your privacy setting…'),
                ),
                error: (error, _) => ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: const Text('Step sharing setting unavailable'),
                  subtitle: Text('$error'),
                ),
                data: (enabled) => SwitchListTile.adaptive(
                  secondary: const Icon(Icons.directions_walk_outlined),
                  title: const Text('Share today’s steps'),
                  subtitle: Text(
                    enabled
                        ? 'Sharing only today’s total and its update time with group members.'
                        : 'Off. Your steps are not visible to group members.',
                  ),
                  value: enabled,
                  onChanged: (value) => _setSharing(context, ref, value),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text(
                  'Age, height, weight, gender, step history, distance, calories and goals stay on this device. Turning sharing off removes your shared step count from every group.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('Your groups', style: Theme.of(context).textTheme.titleLarge)),
            IconButton.filledTonal(
              tooltip: 'Join with invite code',
              onPressed: () => _joinGroup(context, ref),
              icon: const Icon(Icons.key_outlined),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Create group',
              onPressed: () => _createGroup(context, ref),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        groups.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => _ErrorPanel(message: 'Could not load your groups: $error'),
          data: (items) => items.isEmpty
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      children: [
                        Icon(Icons.group_add_outlined, size: 36, color: colors.primary),
                        const SizedBox(height: 10),
                        Text('No groups yet', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        const Text('Create a private group or join a friend with an invite code.', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final group in items)
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colors.primaryContainer,
                            foregroundColor: colors.onPrimaryContainer,
                            child: const Icon(Icons.groups_2_outlined),
                          ),
                          title: Text(group.name),
                          subtitle: const Text('Private · members only'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => GroupDetailScreen(group: group, currentUid: user.uid),
                            ),
                          ),
                          onLongPress: () => _createInvite(context, ref, group),
                        ),
                      ),
                  ],
                ),
        ),
        if (groups.valueOrNull?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          const Text('Open a group to see members. Long-press a group or open it to create an invite.', textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({required this.group, required this.currentUid, super.key});

  final GroupSummary group;
  final String currentUid;

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    try {
      final code = await ref.read(groupServiceProvider).createInvite(
            groupId: group.id,
            creatorUid: currentUid,
          );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Private invite code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Anyone with this code can request to join until it expires in 7 days.'),
              const SizedBox(height: 14),
              SelectableText(code, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite code copied.')));
              },
              child: const Text('Copy'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _showError(context, 'Could not create an invite: $error');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(groupMembersProvider(group.id));
    final sharedSteps = ref.watch(groupSharedStepsProvider(group.id));
    final todayKey = DayRecord.dateKeyFor(DateTime.now());
    final stepsByUid = <String, SharedStepCount>{
      for (final item in sharedSteps.valueOrNull ?? const <SharedStepCount>[])
        if (item.updatedAt != null &&
            DayRecord.dateKeyFor(item.updatedAt!.toLocal()) == todayKey)
          item.uid: item,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            tooltip: 'Invite a friend',
            onPressed: () => _invite(context, ref),
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Only group members can view the roster and opted-in step totals.'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Today', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          sharedSteps.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => _ErrorPanel(message: 'Could not load shared steps: $error'),
            data: (_) => const SizedBox.shrink(),
          ),
          members.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ErrorPanel(message: 'Could not load members: $error'),
            data: (items) => Column(
              children: [
                for (final member in items)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          member.displayName.isEmpty
                              ? '?'
                              : String.fromCharCode(member.displayName.runes.first).toUpperCase(),
                        ),
                      ),
                      title: Text('${member.displayName}${member.uid == currentUid ? ' (you)' : ''}'),
                      subtitle: _stepSubtitle(stepsByUid[member.uid]),
                      trailing: stepsByUid.containsKey(member.uid)
                          ? Text(
                              NumberFormat.decimalPattern().format(stepsByUid[member.uid]!.steps),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            )
                          : const Icon(Icons.visibility_off_outlined),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('A member who has not opted in, or whose total has not been updated today, appears as “Not shared today.”'),
        ],
      ),
    );
  }

  Widget _stepSubtitle(SharedStepCount? shared) {
    if (shared == null) return const Text('Not shared today');
    final at = shared.updatedAt;
    return Text(at == null ? 'Updated today' : 'Updated ${DateFormat.jm().format(at.toLocal())}');
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
