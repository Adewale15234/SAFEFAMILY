import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CloudFamilyMembersSection extends StatelessWidget {
  const CloudFamilyMembersSection({super.key, required this.familyId});

  final String familyId;

  static const Color _green = Color(0xFF16D9A0);
  static const Color _muted = Color(0xFF9AAEA5);
  static const Color _surface = Color(0xFF151F1C);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Text('Sign in to view connected family accounts.');
    }

    final stream = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('members')
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _notice(
            Icons.cloud_off_rounded,
            'Unable to load family accounts',
            'Check your connection and Firestore permissions. '
                'Your existing household contacts have not been changed.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: _green),
            ),
          );
        }

        final docs =
            (snapshot.data?.docs ?? [])
                .where((doc) => doc.data()['status'] == 'active')
                .toList()
              ..sort((a, b) {
                final aName = (a.data()['displayName'] as String? ?? '')
                    .toLowerCase();
                final bName = (b.data()['displayName'] as String? ?? '')
                    .toLowerCase();
                return aName.compareTo(bName);
              });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CONNECTED FAMILY ACCOUNTS',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${docs.length} ${docs.length == 1 ? 'account' : 'accounts'}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              _notice(
                Icons.people_outline_rounded,
                'No connected accounts yet',
                'Family accounts appear here after someone signs in '
                    'and accepts an invitation.',
              )
            else
              ...docs.map((doc) {
                final data = doc.data();
                final name = (data['displayName'] as String?)?.trim() ?? '';
                final email = (data['email'] as String?)?.trim() ?? '';
                final role = data['role'] == 'owner'
                    ? 'Family owner'
                    : 'Member';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF293831)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0x2216D9A0),
                        child: Icon(Icons.person_rounded, color: _green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Family member' : name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              role,
                              style: const TextStyle(
                                color: _green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (doc.id == currentUser.uid)
                        const Tooltip(
                          message: 'Your account',
                          child: Icon(
                            Icons.verified_user_outlined,
                            color: _muted,
                            size: 19,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
            const Text(
              'These are registered accounts with active membership. '
              'Their GPS locations are not shared by this list.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
            ),
          ],
        );
      },
    );
  }

  Widget _notice(IconData icon, String title, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF293831)),
      ),
      child: Column(
        children: [
          Icon(icon, color: _green, size: 30),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}
