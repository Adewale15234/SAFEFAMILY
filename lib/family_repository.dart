import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles cloud family profiles, membership, and invitations.
///
/// Existing local SharedPreferences data is never migrated or deleted here.
class FamilyRepository {
  FamilyRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _families =>
      _firestore.collection('families');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  User _requireSignedInUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Sign in before accessing a cloud family.');
    }
    return user;
  }

  String _displayName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final emailName = user.email?.split('@').first.trim();
    if (emailName != null && emailName.isNotEmpty) return emailName;

    return 'Family member';
  }

  String _requireEmail(User user) {
    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      throw StateError('Your account needs an email address to join a family.');
    }
    return email;
  }

  /// Returns the current account's active family ID, or null if none exists.
  Future<String?> getMyFamilyId() async {
    final user = _requireSignedInUser();
    final indexSnapshot = await _users.doc(user.uid).get();

    if (!indexSnapshot.exists) return null;

    final index = indexSnapshot.data()!;
    final familyId = index['familyId'];

    if (index['uid'] != user.uid ||
        index['status'] != 'active' ||
        familyId is! String ||
        familyId.trim().isEmpty) {
      throw StateError('Your family account record is invalid.');
    }

    final membership = await _families
        .doc(familyId)
        .collection('members')
        .doc(user.uid)
        .get();

    if (!membership.exists ||
        membership.data()?['status'] != 'active' ||
        membership.data()?['role'] != index['role']) {
      throw StateError(
        'Your family account record does not match an active membership.',
      );
    }

    return familyId;
  }

  /// Finds and returns the signed-in user's active family profile.
  /// The returned map includes the document's familyId.
  Future<Map<String, dynamic>?> getMyFamily() async {
    final familyId = await getMyFamilyId();
    if (familyId == null) return null;

    final snapshot = await _families.doc(familyId).get();
    final data = snapshot.data();

    if (data == null) {
      throw StateError('The family profile could not be found.');
    }

    return {...data, 'familyId': familyId};
  }

  /// Reads a family profile after verifying active membership.
  Future<Map<String, dynamic>?> getFamily(String familyId) async {
    final user = _requireSignedInUser();
    final cleanedId = familyId.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError.value(familyId, 'familyId', 'Cannot be empty.');
    }

    final memberSnapshot = await _families
        .doc(cleanedId)
        .collection('members')
        .doc(user.uid)
        .get();

    if (!memberSnapshot.exists ||
        memberSnapshot.data()?['status'] != 'active') {
      throw StateError('You are not an active member of this family.');
    }

    final familySnapshot = await _families.doc(cleanedId).get();
    final data = familySnapshot.data();

    return data == null ? null : {...data, 'familyId': cleanedId};
  }

  /// Creates a family, owner membership, and account index atomically.
  ///
  /// Existing local family details are not uploaded automatically.
  Future<String> createFamily({
    required String familyName,
    required String guardianName,
    required String phone,
    required String city,
  }) async {
    final user = _requireSignedInUser();

    final cleanedFamilyName = familyName.trim();
    final cleanedGuardianName = guardianName.trim();

    if (cleanedFamilyName.isEmpty || cleanedGuardianName.isEmpty) {
      throw ArgumentError('Family name and guardian name cannot be empty.');
    }

    final existingIndex = await _users.doc(user.uid).get();
    if (existingIndex.exists) {
      throw StateError(
        'This account already has a family record. '
        'Load or resolve that family before creating another.',
      );
    }

    final familyRef = _families.doc();
    final memberRef = familyRef.collection('members').doc(user.uid);
    final userRef = _users.doc(user.uid);
    final batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();

    batch.set(familyRef, {
      'ownerUid': user.uid,
      'familyName': cleanedFamilyName,
      'guardianName': cleanedGuardianName,
      'phone': phone.trim(),
      'city': city.trim(),
      'createdAt': timestamp,
      'updatedAt': timestamp,
    });

    batch.set(memberRef, {
      'uid': user.uid,
      'role': 'owner',
      'status': 'active',
      'joinedAt': timestamp,
      'displayName': _displayName(user),
      'email': user.email?.trim().toLowerCase() ?? '',
      'invitationId': '',
    });

    batch.set(userRef, {
      'uid': user.uid,
      'familyId': familyRef.id,
      'role': 'owner',
      'status': 'active',
      'updatedAt': timestamp,
    });

    await batch.commit();
    return familyRef.id;
  }

  /// Updates only family profile fields allowed by firestore.rules.
  Future<void> updateFamily({
    required String familyId,
    required String familyName,
    required String guardianName,
    required String phone,
    required String city,
  }) async {
    final user = _requireSignedInUser();
    final cleanedId = familyId.trim();
    final cleanedFamilyName = familyName.trim();
    final cleanedGuardianName = guardianName.trim();

    if (cleanedId.isEmpty) {
      throw ArgumentError.value(familyId, 'familyId', 'Cannot be empty.');
    }
    if (cleanedFamilyName.isEmpty || cleanedGuardianName.isEmpty) {
      throw ArgumentError('Family name and guardian name cannot be empty.');
    }

    final familyIdForAccount = await getMyFamilyId();
    if (familyIdForAccount != cleanedId) {
      throw StateError(
        'Only your current family can be updated from this account.',
      );
    }

    await _families.doc(cleanedId).update({
      'familyName': cleanedFamilyName,
      'guardianName': cleanedGuardianName,
      'phone': phone.trim(),
      'city': city.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Keep the user variable referenced as the authenticated caller.
    assert(user.uid.isNotEmpty);
  }

  /// Creates a pending invitation that expires after the specified duration.
  Future<String> createInvitation({
    required String familyId,
    required String invitedEmail,
    Duration validity = const Duration(days: 7),
  }) async {
    final user = _requireSignedInUser();
    final cleanedFamilyId = familyId.trim();
    final email = invitedEmail.trim().toLowerCase();

    if (cleanedFamilyId.isEmpty) {
      throw ArgumentError.value(familyId, 'familyId', 'Cannot be empty.');
    }
    if (!email.contains('@') || email.startsWith('@') || email.endsWith('@')) {
      throw ArgumentError.value(
        invitedEmail,
        'invitedEmail',
        'Enter a valid email address.',
      );
    }
    if (validity <= Duration.zero || validity > const Duration(days: 30)) {
      throw ArgumentError(
        'Invitation validity must be greater than zero and no more than 30 days.',
      );
    }

    if (await getMyFamilyId() != cleanedFamilyId) {
      throw StateError('You do not belong to this family.');
    }

    final memberSnapshot = await _families
        .doc(cleanedFamilyId)
        .collection('members')
        .doc(user.uid)
        .get();

    if (memberSnapshot.data()?['role'] != 'owner') {
      throw StateError('Only the family owner can invite members.');
    }

    final invitationRef = _families
        .doc(cleanedFamilyId)
        .collection('invitations')
        .doc();

    await invitationRef.set({
      'invitedEmail': email,
      'invitedBy': user.uid,
      'status': 'pending',
      'role': 'member',
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(validity)),
      'acceptedBy': '',
      'acceptedAt': null,
    });

    return invitationRef.id;
  }

  /// Accepts an invitation and creates membership and account index atomically.
  Future<String> acceptInvitation({
    required String familyId,
    required String invitationId,
  }) async {
    final user = _requireSignedInUser();
    final email = _requireEmail(user);
    final cleanedFamilyId = familyId.trim();
    final cleanedInvitationId = invitationId.trim();

    if (cleanedFamilyId.isEmpty || cleanedInvitationId.isEmpty) {
      throw ArgumentError('Family ID and invitation ID are required.');
    }

    final userRef = _users.doc(user.uid);
    final existingIndex = await userRef.get();
    if (existingIndex.exists) {
      throw StateError(
        'This account already has a family record. '
        'Resolve that membership before accepting another invitation.',
      );
    }

    final familyRef = _families.doc(cleanedFamilyId);
    final invitationRef = familyRef
        .collection('invitations')
        .doc(cleanedInvitationId);

    final invitationSnapshot = await invitationRef.get();
    final invitation = invitationSnapshot.data();

    if (invitation == null) {
      throw StateError('This invitation could not be found.');
    }
    if (invitation['status'] != 'pending') {
      throw StateError('This invitation is no longer pending.');
    }
    if ((invitation['invitedEmail'] as String?)?.toLowerCase() != email) {
      throw StateError('This invitation belongs to a different email address.');
    }

    final expiry = invitation['expiresAt'];
    if (expiry is! Timestamp || !expiry.toDate().isAfter(DateTime.now())) {
      throw StateError('This invitation has expired.');
    }

    final memberRef = familyRef.collection('members').doc(user.uid);
    final batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();

    batch.update(invitationRef, {
      'status': 'accepted',
      'acceptedBy': user.uid,
      'acceptedAt': timestamp,
    });

    batch.set(memberRef, {
      'uid': user.uid,
      'role': 'member',
      'status': 'active',
      'joinedAt': timestamp,
      'displayName': _displayName(user),
      'email': email,
      'invitationId': cleanedInvitationId,
    });

    batch.set(userRef, {
      'uid': user.uid,
      'familyId': cleanedFamilyId,
      'role': 'member',
      'status': 'active',
      'updatedAt': timestamp,
    });

    await batch.commit();
    return cleanedFamilyId;
  }
}
