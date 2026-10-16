// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/day_record.dart';

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    required this.joinedAt,
  });

  final String id;
  final String name;
  final DateTime? joinedAt;

  factory GroupSummary.fromMap(String id, Map<String, dynamic> map) {
    final joinedAt = map['joinedAt'];
    return GroupSummary(
      id: id,
      name: (map['name'] as String?) ?? 'Stride group',
      joinedAt: joinedAt is Timestamp ? joinedAt.toDate() : null,
    );
  }
}

class GroupMember {
  const GroupMember({
    required this.uid,
    required this.displayName,
    required this.role,
  });

  final String uid;
  final String displayName;
  final String role;

  factory GroupMember.fromMap(String uid, Map<String, dynamic> map) {
    return GroupMember(
      uid: uid,
      displayName: (map['displayName'] as String?) ?? 'Stride member',
      role: (map['role'] as String?) ?? 'member',
    );
  }
}

class SharedStepCount {
  const SharedStepCount({
    required this.uid,
    required this.steps,
    required this.updatedAt,
  });

  final String uid;
  final int steps;
  final DateTime? updatedAt;

  factory SharedStepCount.fromMap(String uid, Map<String, dynamic> map) {
    final timestamp = map['updatedAt'];
    return SharedStepCount(
      uid: uid,
      steps: (map['steps'] as num?)?.toInt() ?? 0,
      updatedAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

/// Firestore operations for private groups. No local profile or step-history
/// model is serialized here: step documents contain only today's count and a
/// server update timestamp.
class GroupService {
  GroupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _sharingPreferencePrefix = 'stride.shareToday.';
  static const _inviteAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  final Random _random = Random.secure();

  CollectionReference<Map<String, dynamic>> get _groups =>
      _firestore.collection('groups');

  DocumentReference<Map<String, dynamic>> _userGroup(String uid, String id) =>
      _firestore.collection('users').doc(uid).collection('groups').doc(id);

  DocumentReference<Map<String, dynamic>> _member(String groupId, String uid) =>
      _groups.doc(groupId).collection('members').doc(uid);

  DocumentReference<Map<String, dynamic>> _steps(String groupId, String uid) =>
      _groups.doc(groupId).collection('steps').doc(uid);

  Stream<List<GroupSummary>> watchGroups(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('groups')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => GroupSummary.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));

  Stream<List<GroupMember>> watchMembers(String groupId) =>
      _groups.doc(groupId).collection('members').snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => GroupMember.fromMap(doc.id, doc.data()))
                .toList()
              ..sort((a, b) => a.displayName
                  .toLowerCase()
                  .compareTo(b.displayName.toLowerCase())),
          );

  Stream<List<SharedStepCount>> watchSharedSteps(String groupId) =>
      _groups.doc(groupId).collection('steps').snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => SharedStepCount.fromMap(doc.id, doc.data()))
                .toList(),
          );

  Future<GroupSummary> createGroup({
    required String uid,
    required String displayName,
    required String name,
  }) async {
    final groupName = name.trim();
    if (groupName.length < 2 || groupName.length > 40) {
      throw ArgumentError('Group name must be between 2 and 40 characters.');
    }
    final group = _groups.doc();
    final batch = _firestore.batch();
    batch.set(group, {
      'name': groupName,
      'ownerUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(_member(group.id, uid), {
      'uid': uid,
      'displayName': _safeDisplayName(displayName),
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_userGroup(uid, group.id), {
      'groupId': group.id,
      'name': groupName,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return GroupSummary(id: group.id, name: groupName, joinedAt: DateTime.now());
  }

  Future<String> createInvite({
    required String groupId,
    required String creatorUid,
  }) async {
    final groupSnapshot = await _groups.doc(groupId).get();
    final groupName = groupSnapshot.data()?['name'] as String?;
    if (groupName == null) throw StateError('This group is no longer available.');
    final code = List.generate(
      22,
      (_) => _inviteAlphabet[_random.nextInt(_inviteAlphabet.length)],
    ).join();
    final invite = _firestore.collection('invites').doc(code);
    await invite.set({
      'groupId': groupId,
      'groupName': groupName,
      'createdBy': creatorUid,
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      ),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  Future<GroupSummary> joinByInvite({
    required String uid,
    required String displayName,
    required String code,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.length != 22) {
      throw ArgumentError('Enter the full 22-character invite code.');
    }
    late final DocumentSnapshot<Map<String, dynamic>> inviteSnapshot;
    try {
      inviteSnapshot =
          await _firestore.collection('invites').doc(normalized).get();
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw StateError('That invite is invalid or has expired.');
      }
      rethrow;
    }
    final invite = inviteSnapshot.data();
    if (invite == null) throw StateError('That invite code was not found.');
    final expiresAt = invite['expiresAt'];
    if (expiresAt is! Timestamp || expiresAt.toDate().isBefore(DateTime.now())) {
      throw StateError('That invite has expired. Ask a group member for a new one.');
    }
    final groupId = invite['groupId'] as String?;
    final groupName = invite['groupName'] as String? ?? 'Stride group';
    if (groupId == null || groupId.isEmpty) {
      throw StateError('This invite is invalid. Ask for a new one.');
    }

    final memberRef = _member(groupId, uid);
    final existing = await memberRef.get();
    if (existing.exists) {
      return GroupSummary(id: groupId, name: groupName, joinedAt: DateTime.now());
    }

    final batch = _firestore.batch();
    batch.set(memberRef, {
      'uid': uid,
      'displayName': _safeDisplayName(displayName),
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
      // Kept as proof for Firestore rules while the invite is valid. It is
      // visible only to members of this private group.
      'inviteCode': normalized,
    });
    batch.set(_userGroup(uid, groupId), {
      'groupId': groupId,
      'name': groupName,
      'joinedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    try {
      await memberRef.update({'inviteCode': FieldValue.delete()});
    } on FirebaseException {
      // Membership is already committed. If this cleanup cannot complete,
      // the retained invite code is still visible only to group members.
    }
    return GroupSummary(id: groupId, name: groupName, joinedAt: DateTime.now());
  }

  Future<bool> sharingEnabled(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_sharingPreferencePrefix$uid') ?? false;
  }

  Future<void> setSharingEnabled(String uid, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_sharingPreferencePrefix$uid', enabled);
    if (!enabled) await clearStepShares(uid);
  }

  Future<void> publishTodaySteps({
    required String uid,
    required DayRecord record,
  }) async {
    if (!await sharingEnabled(uid)) return;
    final groups = await _firestore
        .collection('users')
        .doc(uid)
        .collection('groups')
        .get();
    final docs = groups.docs;
    for (var start = 0; start < docs.length; start += 450) {
      final batch = _firestore.batch();
      for (final group in docs.skip(start).take(450)) {
        batch.set(_steps(group.id, uid), {
          'steps': record.steps,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> clearStepShares(String uid) async {
    final groups = await _firestore
        .collection('users')
        .doc(uid)
        .collection('groups')
        .get();
    final docs = groups.docs;
    for (var start = 0; start < docs.length; start += 450) {
      final batch = _firestore.batch();
      for (final group in docs.skip(start).take(450)) {
        batch.delete(_steps(group.id, uid));
      }
      await batch.commit();
    }
  }

  static String _safeDisplayName(String value) {
    final name = value.trim();
    return name.isEmpty ? 'Stride member' : name.substring(0, min(name.length, 40));
  }
}
