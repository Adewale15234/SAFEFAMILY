import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SosDeliveryStatus { delivered, queued }

class SosSubmissionResult {
  const SosSubmissionResult({required this.alertId, required this.status});

  final String alertId;
  final SosDeliveryStatus status;
}

class _PendingSos {
  const _PendingSos({
    required this.alertId,
    required this.uid,
    required this.familyId,
    required this.senderName,
    required this.message,
    required this.queuedAt,
  });

  final String alertId;
  final String uid;
  final String familyId;
  final String senderName;
  final String message;
  final String queuedAt;

  Map<String, dynamic> toJson() => {
    'alertId': alertId,
    'uid': uid,
    'familyId': familyId,
    'senderName': senderName,
    'message': message,
    'queuedAt': queuedAt,
  };

  factory _PendingSos.fromJson(Map<String, dynamic> json) {
    return _PendingSos(
      alertId: json['alertId'] as String,
      uid: json['uid'] as String,
      familyId: json['familyId'] as String,
      senderName: json['senderName'] as String,
      message: json['message'] as String,
      queuedAt: json['queuedAt'] as String,
    );
  }
}

class EmergencyService {
  EmergencyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const String _queueKey = 'safefamily_pending_sos_v1';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<List<_PendingSos>> _readQueue(SharedPreferences preferences) async {
    final raw = preferences.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => _PendingSos.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (error) {
      debugPrint('Could not read pending SOS queue: $error');
      throw StateError(
        'The pending SOS queue could not be read safely. '
        'Its contents have been preserved.',
      );
    }
  }

  Future<void> _writeQueue(
    SharedPreferences preferences,
    List<_PendingSos> items,
  ) async {
    final success = await preferences.setString(
      _queueKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );

    if (!success) {
      throw StateError('Could not save the pending SOS queue on this device.');
    }
  }

  Future<void> _removeFromQueue(
    SharedPreferences preferences,
    String alertId,
  ) async {
    final items = await _readQueue(preferences);
    items.removeWhere((item) => item.alertId == alertId);
    await _writeQueue(preferences, items);
  }

  bool _isTemporaryNetworkError(Object error) {
    if (error is TimeoutException) return true;

    if (error is FirebaseException) {
      return {
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
      }.contains(error.code);
    }

    return false;
  }

  Future<SosSubmissionResult> submitSosAlert({
    required String familyId,
    required String senderName,
    String message = 'Emergency SOS triggered from SAFEFAMILY.',
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Sign in before sending an SOS.');
    }

    if (familyId.trim().isEmpty) {
      throw StateError('Join or create a family before sending an SOS.');
    }

    final safeName = senderName.trim().isEmpty
        ? 'Family member'
        : senderName.trim().substring(
            0,
            senderName.trim().length > 100 ? 100 : senderName.trim().length,
          );

    final safeMessage = message.length > 500
        ? message.substring(0, 500)
        : message;

    final familyReference = _firestore.collection('families').doc(familyId);

    final alertId = familyReference.collection('emergencies').doc().id;

    final pending = _PendingSos(
      alertId: alertId,
      uid: user.uid,
      familyId: familyId,
      senderName: safeName,
      message: safeMessage,
      queuedAt: DateTime.now().toUtc().toIso8601String(),
    );

    final preferences = await SharedPreferences.getInstance();
    final items = await _readQueue(preferences);
    items.add(pending);

    // Persist first, before attempting a network operation.
    await _writeQueue(preferences, items);

    try {
      await _uploadPending(pending);
      await _removeFromQueue(preferences, alertId);

      return SosSubmissionResult(
        alertId: alertId,
        status: SosDeliveryStatus.delivered,
      );
    } catch (error) {
      if (_isTemporaryNetworkError(error)) {
        debugPrint('SOS $alertId queued for later delivery: $error');

        return SosSubmissionResult(
          alertId: alertId,
          status: SosDeliveryStatus.queued,
        );
      }

      // A rules, authentication, or validation error is not proof of
      // a network outage. Do not mislabel it as a pending SOS.
      await _removeFromQueue(preferences, alertId);
      rethrow;
    }
  }

  Future<void> _uploadPending(_PendingSos pending) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null || currentUser.uid != pending.uid) {
      throw StateError(
        'Sign in to the original account before retrying this SOS.',
      );
    }

    final reference = _firestore
        .collection('families')
        .doc(pending.familyId)
        .collection('emergencies')
        .doc(pending.alertId);

    // Check the server, not just Firestore's local cache. This handles
    // an earlier upload whose acknowledgement was lost or delayed.
    final existing = await reference
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));

    if (existing.exists) {
      final data = existing.data();

      if (data?['createdBy'] != pending.uid) {
        throw StateError('The SOS document ID belongs to a different account.');
      }

      return;
    }

    double? latitude;
    double? longitude;
    double? accuracy;
    Timestamp? locationUpdatedAt;

    try {
      final location = await _firestore
          .collection('families')
          .doc(pending.familyId)
          .collection('locations')
          .doc(pending.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));

      final data = location.data();
      if (location.exists && data != null) {
        final lat = data['latitude'];
        final lon = data['longitude'];
        final acc = data['accuracy'];
        final updatedAt = data['updatedAt'];

        if (lat is num &&
            lon is num &&
            acc is num &&
            updatedAt is Timestamp &&
            lat >= -90 &&
            lat <= 90 &&
            lon >= -180 &&
            lon <= 180 &&
            acc >= 0) {
          latitude = lat.toDouble();
          longitude = lon.toDouble();
          accuracy = acc.toDouble();
          locationUpdatedAt = updatedAt;
        }
      }
    } catch (error) {
      // Location is optional. An SOS can still be recorded without it.
      debugPrint('SOS location unavailable: $error');
    }

    await reference
        .set({
          'createdBy': pending.uid,
          'senderName': pending.senderName,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'locationUpdatedAt': locationUpdatedAt,
          'message': pending.message,
        })
        .timeout(const Duration(seconds: 10));

    // The server will confirm existence on the next retry if the write
    // was accepted but its acknowledgement was delayed.
  }

  /// Retries alerts belonging to the currently signed-in user and
  /// the currently active family. Other queue entries are left untouched.
  Future<int> retryPendingSos({required String familyId}) async {
    final user = _auth.currentUser;
    if (user == null || familyId.isEmpty) return 0;

    final preferences = await SharedPreferences.getInstance();
    final items = await _readQueue(preferences);
    var delivered = 0;

    for (final pending in items) {
      if (pending.uid != user.uid || pending.familyId != familyId) {
        continue;
      }

      try {
        await _uploadPending(pending);
        await _removeFromQueue(preferences, pending.alertId);
        delivered++;
      } catch (error) {
        debugPrint('Pending SOS ${pending.alertId} remains queued: $error');

        if (_isTemporaryNetworkError(error)) {
          // Avoid repeatedly attempting the remaining records offline.
          break;
        }
      }
    }

    return delivered;
  }
}
