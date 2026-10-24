import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'family_repository.dart';

/// Handles permission-based foreground location sharing for an active family.
class LocationSharingService {
  LocationSharingService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FamilyRepository? familyRepository,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _familyRepository = familyRepository ?? FamilyRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FamilyRepository _familyRepository;

  Future<String> _requireOwnFamily(String requestedFamilyId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before sharing your location.');
    }

    final activeFamilyId = await _familyRepository.getMyFamilyId();
    if (activeFamilyId == null || activeFamilyId != requestedFamilyId) {
      throw StateError('Your account is not an active member of this family.');
    }

    return user.uid;
  }

  /// Publishes this signed-in member's latest GPS position.
  ///
  /// The document fields intentionally match the existing Firestore rules.
  Future<void> publishPosition({
    required String familyId,
    required Position position,
  }) async {
    final uid = await _requireOwnFamily(familyId);

    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('locations')
        .doc(uid)
        .set({
          'uid': uid,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'updatedAt': FieldValue.serverTimestamp(),
          'sharingEnabled': true,
        });
  }

  /// Stops publishing by removing this member's location document.
  Future<void> stopSharing({required String familyId}) async {
    final uid = await _requireOwnFamily(familyId);

    await _firestore
        .collection('families')
        .doc(familyId)
        .collection('locations')
        .doc(uid)
        .delete();
  }

  /// Streams the latest location records visible to active family members.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchFamilyLocations(
    String familyId,
  ) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('locations')
        .snapshots();
  }

  /// Streams family membership documents so map markers can show member names.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchFamilyMembers(
    String familyId,
  ) {
    return _firestore
        .collection('families')
        .doc(familyId)
        .collection('members')
        .where('status', isEqualTo: 'active')
        .snapshots();
  }
}
