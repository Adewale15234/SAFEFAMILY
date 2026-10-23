import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'family_repository.dart';

class FamilyInvitationsPage extends StatefulWidget {
  const FamilyInvitationsPage({super.key});

  @override
  State<FamilyInvitationsPage> createState() => _FamilyInvitationsPageState();
}

class _FamilyInvitationsPageState extends State<FamilyInvitationsPage> {
  final _emailController = TextEditingController();
  final _familyIdController = TextEditingController();
  final _invitationIdController = TextEditingController();

  String? _myFamilyId;
  String? _createdInvitationId;
  bool _loadingFamily = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadFamily();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _familyIdController.dispose();
    _invitationIdController.dispose();
    super.dispose();
  }

  Future<void> _loadFamily() async {
    try {
      final id = await FamilyRepository().getMyFamilyId();
      if (!mounted) return;
      setState(() {
        _myFamilyId = id;
        _loadingFamily = false;
      });
    } catch (error) {
      debugPrint('Could not load family for invitations: $error');
      if (!mounted) return;
      setState(() => _loadingFamily = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createInvitation() async {
    if (_busy) return;

    final email = _emailController.text.trim().toLowerCase();
    if (!email.contains('@') || email.startsWith('@') || email.endsWith('@')) {
      _message('Enter the invited person’s valid email address.');
      return;
    }

    if (_myFamilyId == null) {
      _message(
        'Create a cloud family first. Only a family owner can invite members.',
      );
      return;
    }

    final currentEmail = FirebaseAuth.instance.currentUser?.email
        ?.trim()
        .toLowerCase();
    if (currentEmail == email) {
      _message('Use the other person’s email address, not your own.');
      return;
    }

    setState(() => _busy = true);

    try {
      final id = await FamilyRepository().createInvitation(
        familyId: _myFamilyId!,
        invitedEmail: email,
      );

      if (!mounted) return;
      setState(() => _createdInvitationId = id);
      _message('Invitation created. Share the details privately.');
    } catch (error) {
      debugPrint('Invitation creation failed: $error');
      _message('Could not create invitation: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptInvitation() async {
    if (_busy) return;

    final familyId = _familyIdController.text.trim();
    final invitationId = _invitationIdController.text.trim();

    if (familyId.isEmpty || invitationId.isEmpty) {
      _message('Enter both the family ID and invitation ID.');
      return;
    }

    setState(() => _busy = true);

    try {
      await FamilyRepository().acceptInvitation(
        familyId: familyId,
        invitationId: invitationId,
      );

      if (!mounted) return;
      _message('You joined the family successfully. Reloading family data…');

      // Return to the dashboard so it can refresh its family information.
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Invitation acceptance failed: $error');
      _message(
        'Could not accept invitation. Check the IDs, signed-in email, '
        'expiry, and whether this account already belongs to a family.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyInvitation() async {
    final id = _createdInvitationId;
    final familyId = _myFamilyId;
    final email = _emailController.text.trim();

    if (id == null || familyId == null) return;

    final message =
        'SAFEFAMILY family invitation\n'
        'Invited email: $email\n'
        'Family ID: $familyId\n'
        'Invitation ID: $id\n'
        'Sign in to SAFEFAMILY using the invited email, then open '
        'Family > Invitations / Join family and enter these IDs.';

    await Clipboard.setData(ClipboardData(text: message));
    _message('Invitation details copied. Send them privately.');
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF9AAEA5), height: 1.4),
        ),
      ],
    );
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Family invitations')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(
              Icons.diversity_3_rounded,
              size: 52,
              color: Color(0xFF16D9A0),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect your family securely',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Signed in as: ${signedIn?.email ?? 'No email available'}',
              style: const TextStyle(color: Color(0xFF9AAEA5)),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle(
                      '1. Invite a family member',
                      'Available to the owner of an existing cloud family. '
                          'The invitation expires after seven days.',
                    ),
                    const SizedBox(height: 16),
                    if (_loadingFamily)
                      const Center(child: CircularProgressIndicator())
                    else if (_myFamilyId == null)
                      const Text(
                        'No cloud family found for this account. '
                        'Create your cloud family from the Family tab first.',
                        style: TextStyle(color: Color(0xFFFFCC80)),
                      )
                    else
                      Text(
                        'Your family ID: $_myFamilyId',
                        style: const TextStyle(color: Color(0xFF9AAEA5)),
                      ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: _decoration(
                        'Invited person’s email',
                        Icons.email_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _busy || _loadingFamily || _myFamilyId == null
                          ? null
                          : _createInvitation,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(_busy ? 'Please wait…' : 'Create invitation'),
                    ),
                    if (_createdInvitationId != null) ...[
                      const SizedBox(height: 14),
                      SelectableText('Family ID: $_myFamilyId'),
                      const SizedBox(height: 8),
                      SelectableText('Invitation ID: $_createdInvitationId'),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _copyInvitation,
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy invitation details'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle(
                      '2. Join a family',
                      'If someone invited you, sign in with the exact email '
                          'address the owner invited, then enter both IDs.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _familyIdController,
                      autocorrect: false,
                      decoration: _decoration(
                        'Family ID',
                        Icons.groups_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _invitationIdController,
                      autocorrect: false,
                      decoration: _decoration(
                        'Invitation ID',
                        Icons.confirmation_number_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy ? null : _acceptInvitation,
                      icon: const Icon(Icons.login_rounded),
                      label: Text(_busy ? 'Please wait…' : 'Accept invitation'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Acceptance is checked by Firestore rules. A contact '
                      'saved on another phone is not automatically an account '
                      'or a live location-sharing participant.',
                      style: TextStyle(
                        color: Color(0xFF9AAEA5),
                        height: 1.4,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
