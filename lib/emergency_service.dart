import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class EmergencyService {
  EmergencyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<String> createSosAlert({
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

    double? latitude;
    double? longitude;
    double? accuracy;
    Timestamp? locationUpdatedAt;

    // Include the latest published location when it is available.
    try {
      final snapshot = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('locations')
          .doc(user.uid)
          .get();

      final data = snapshot.data();
      if (snapshot.exists && data != null) {
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
      debugPrint('SOS location snapshot unavailable: $error');
    }

    final trimmedName = senderName.trim();
    final safeName = trimmedName.isEmpty
        ? 'Family member'
        : trimmedName.length > 100
        ? trimmedName.substring(0, 100)
        : trimmedName;

    final safeMessage = message.length > 500
        ? message.substring(0, 500)
        : message;

    final reference = _firestore
        .collection('families')
        .doc(familyId)
        .collection('emergencies')
        .doc();

    await reference.set({
      'createdBy': user.uid,
      'senderName': safeName,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'locationUpdatedAt': locationUpdatedAt,
      'message': safeMessage,
    });

    return reference.id;
  }
}
