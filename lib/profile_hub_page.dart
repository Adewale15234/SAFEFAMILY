// SAFEFAMILY Profile Hub
// A dedicated profile, settings, help, about, support, privacy, and update centre.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileHubPage extends StatelessWidget {
  const ProfileHubPage({
    super.key,
    required this.currentUser,
    required this.guardianName,
    required this.familyName,
    required this.phone,
    required this.city,
    required this.onEditFamily,
    required this.onSignOut,
  });

  final User? currentUser;
  final String guardianName;
  final String familyName;
  final String phone;
  final String city;
  final VoidCallback onEditFamily;
  final Future<void> Function() onSignOut;

  static const _bg = Color(0xFF07110D);
  static const _surface = Color(0xFF101D17);
  static const _border = Color(0xFF263B30);
  static const _green = Color(0xFF68E0A4);
  static const _muted = Color(0xFFA4B8AC);

  @override
  Widget build(BuildContext context) {
    final displayName = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!.trim()
        : (guardianName.trim().isNotEmpty
              ? guardianName.trim()
              : (currentUser?.email?.split('@').first ?? 'SAFEFAMILY user'));
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: [
            const Text(
              'YOUR SPACE',
              style: TextStyle(
                color: _green,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Profile & settings',
              style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Manage your account, learn how SAFEFAMILY works, and get help.',
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1D4936),
                    Color(0xFF10241A),
                    Color(0xFF101D17),
                  ],
                ),
                border: Border.all(color: _green.withValues(alpha: .24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 29,
                        backgroundColor: _green.withValues(alpha: .15),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: _green,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentUser?.email ?? 'Signed-in account',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.verified_user_rounded,
                        color: _green,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: _green),
                        SizedBox(width: 7),
                        Text(
                          'Family safety starts with trust',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionLabel('FAMILY PROFILE'),
            const SizedBox(height: 9),
            _panel([
              _infoRow(
                Icons.groups_2_outlined,
                'Family name',
                familyName.isEmpty ? 'Not set up yet' : familyName,
              ),
              _infoRow(
                Icons.person_outline_rounded,
                'Guardian',
                guardianName.isEmpty ? 'Not provided' : guardianName,
              ),
              _infoRow(
                Icons.phone_outlined,
                'Phone',
                phone.isEmpty ? 'Not provided' : phone,
              ),
              _infoRow(
                Icons.location_city_outlined,
                'City / area',
                city.isEmpty ? 'Not provided' : city,
                last: true,
              ),
              const SizedBox(height: 7),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onEditFamily,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(
                    familyName.isEmpty
                        ? 'Set up family profile'
                        : 'Edit family details',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: _bg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 23),
            _sectionLabel('SAFefamily TOOLS'.toUpperCase()),
            const SizedBox(height: 9),
            _panel([
              _menuTile(
                context,
                Icons.tune_rounded,
                'Settings',
                'Personal preferences and app behaviour',
                () => _push(context, const _SettingsPage()),
              ),
              _menuTile(
                context,
                Icons.menu_book_rounded,
                'User guide',
                'Learn the main features step by step',
                () => _push(context, const _GuidePage()),
              ),
              _menuTile(
                context,
                Icons.system_update_alt_rounded,
                'App updates',
                'Version details, release notes and update guidance',
                () => _push(context, const _UpdatesPage()),
              ),
            ]),
            const SizedBox(height: 17),
            _sectionLabel('INFORMATION & SUPPORT'),
            const SizedBox(height: 9),
            _panel([
              _menuTile(
                context,
                Icons.info_outline_rounded,
                'About SAFEFAMILY',
                'Purpose, version and developer credits',
                () => _push(context, const _AboutPage()),
              ),
              _menuTile(
                context,
                Icons.support_agent_rounded,
                'Contact & support',
                'Help, feedback and support information',
                () => _push(context, const _SupportPage()),
              ),
              _menuTile(
                context,
                Icons.lock_outline_rounded,
                'Privacy & security',
                'Understand location sharing and account safety',
                () => _push(context, const _PrivacyPage()),
              ),
            ]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.offline_bolt_outlined, color: _green, size: 21),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'SAFEFAMILY is being built with low-connectivity use in mind. Some online services and emergency features may not be available until fully configured and tested.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out of SAFEFAMILY'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF8B91),
                side: const BorderSide(color: Color(0xFF66363A)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'SAFEFAMILY  â€¢  Family safety, even without internet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 10, height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your locally saved family profile will not be deleted. You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (yes == true) await onSignOut();
  }

  static Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      color: _muted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );

  static Widget _panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _border),
    ),
    child: Column(children: children),
  );

  static Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 5 : 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _green),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static Widget _menuTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _green.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: _green, size: 21),
    ),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        subtitle,
        style: const TextStyle(color: _muted, fontSize: 11, height: 1.35),
      ),
    ),
    trailing: const Icon(Icons.chevron_right_rounded, color: _muted),
    onTap: onTap,
  );

  static void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

abstract class _ProfileInfoPage extends StatelessWidget {
  const _ProfileInfoPage({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;

  static const bg = Color(0xFF07110D);
  static const surface = Color(0xFF101D17);
  static const border = Color(0xFF263B30);
  static const green = Color(0xFF68E0A4);
  static const muted = Color(0xFFA4B8AC);

  List<Widget> content(BuildContext context);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    appBar: AppBar(backgroundColor: bg, title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: green, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: muted,
                        height: 1.4,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...content(context),
      ],
    ),
  );

  Widget section(String title, String body) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(color: muted, height: 1.6, fontSize: 12),
        ),
      ],
    ),
  );
}

class _GuidePage extends _ProfileInfoPage {
  const _GuidePage()
    : super(
        title: 'User guide',
        subtitle: 'A practical walkthrough of SAFEFAMILY.',
        icon: Icons.menu_book_rounded,
      );

  @override
  List<Widget> content(BuildContext context) => [
    section(
      '1. Set up your family',
      'Open Family and create or edit your family profile. Keep the guardian name, phone number and area accurate. Your profile and your sign-in account are separate things.',
    ),
    section(
      '2. Invite family members',
      'Use Invitations / Join family to follow the available invitation flow. Only share invitations with people you trust, and verify that each person joins the correct family.',
    ),
    section(
      '3. Location sharing',
      'Location sharing requires device location services and your permission. Check the sharing status and last update time. A stale location is not proof that a person is still there.',
    ),
    section(
      '4. Chat and check-ins',
      'Use the Chat area for the features currently available in your build. A preview or sample conversation is not the same as a live, cross-device messaging service.',
    ),
    section(
      '5. Emergency features',
      'Before relying on SOS, verify that alert delivery is configured and tested. A button or preview alone does not contact emergency services or guarantee that family members are notified.',
    ),
    section(
      '6. When internet is unavailable',
      'Some information may remain on the device, but cloud updates, invitations and remote alerts need connectivity. Check the timestamp and reconnect when it is safe to do so.',
    ),
  ];
}

class _AboutPage extends _ProfileInfoPage {
  const _AboutPage()
    : super(
        title: 'About SAFEFAMILY',
        subtitle: 'Family safety, even without internet.',
        icon: Icons.shield_rounded,
      );

  @override
  List<Widget> content(BuildContext context) => [
    section(
      'Our purpose',
      'SAFEFAMILY is an offline-first family-safety project designed to help families stay informed, coordinate check-ins and understand location-sharing status, including in low-connectivity settings.',
    ),
    section(
      'Current release',
      'Version 1.0.0+1\nThis is the version currently declared in the app project.',
    ),
    section(
      'Developer credits',
      'The original developer names have not yet been recovered from the available project backups. They must be restored accurately before this screen is published; no names are guessed here.',
    ),
    section(
      'Feature status',
      'Some screens may still be prototypes. Live messaging, remote notifications, emergency delivery and update checking should only be described as active after implementation and testing.',
    ),
  ];
}

class _SupportPage extends _ProfileInfoPage {
  const _SupportPage()
    : super(
        title: 'Contact & support',
        subtitle: 'Find help and report a problem.',
        icon: Icons.support_agent_rounded,
      );

  @override
  List<Widget> content(BuildContext context) => [
    section(
      'Before requesting help',
      'Include your SAFEFAMILY version, phone model, what you were doing, what you expected, and the exact error message. Do not send passwords, verification codes or private family location details.',
    ),
    section(
      'Support contact',
      'The official support email, phone number and website have not been configured in this project yet. Add verified contact details here before distributing a public release.',
    ),
    section(
      'Feedback',
      'Describe what happened and when. If the issue involves a safety alert or location sharing, do not assume the feature worked unless the app confirms the result and the recipient has verified receipt.',
    ),
  ];
}

class _PrivacyPage extends _ProfileInfoPage {
  const _PrivacyPage()
    : super(
        title: 'Privacy & security',
        subtitle: 'Understand the data and permissions you use.',
        icon: Icons.lock_outline_rounded,
      );

  @override
  List<Widget> content(BuildContext context) => [
    section(
      'Location permissions',
      'Only enable location sharing when you understand who can see the location and why. Review Android location permissions and stop sharing when you no longer want to share.',
    ),
    section(
      'Account security',
      'Use your own account, keep access to your email secure, and never share passwords or sign-in verification codes. Sign out on devices you do not control.',
    ),
    section(
      'Data and connectivity',
      'Local profile information may stay on this device. Cloud family data is subject to the configured Firebase project and its deployed security rules. Offline storage does not guarantee that every feature works offline.',
    ),
    section(
      'Your control',
      'Review app permissions in Android Settings. A full data export, account deletion workflow and published privacy policy must be implemented and verified before public release if they are offered as product features.',
    ),
  ];
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage();

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  static const _bg = Color(0xFF07110D);
  static const _surface = Color(0xFF101D17);
  static const _border = Color(0xFF263B30);
  static const _green = Color(0xFF68E0A4);
  static const _muted = Color(0xFFA4B8AC);
  bool _safetyTips = true;
  bool _updateReminders = true;
  bool _compactCards = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _safetyTips = prefs.getBool('profile_safety_tips_v1') ?? true;
      _updateReminders = prefs.getBool('profile_update_reminders_v1') ?? true;
      _compactCards = prefs.getBool('profile_compact_cards_v1') ?? false;
      _loading = false;
    });
  }

  Future<void> _save(String key, bool value, void Function() update) async {
    setState(update);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preference saved on this device.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(backgroundColor: _bg, title: const Text('Settings')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'PERSONAL PREFERENCES',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              _switchTile(
                'Safety tips',
                'Show helpful safety guidance in the app.',
                _safetyTips,
                (v) =>
                    _save('profile_safety_tips_v1', v, () => _safetyTips = v),
              ),
              _switchTile(
                'Update reminders preference',
                'Remember that you want to be informed about important releases. Push notifications are not configured by this switch.',
                _updateReminders,
                (v) => _save(
                  'profile_update_reminders_v1',
                  v,
                  () => _updateReminders = v,
                ),
              ),
              _switchTile(
                'Compact cards',
                'Save your preference for a denser information layout.',
                _compactCards,
                (v) => _save(
                  'profile_compact_cards_v1',
                  v,
                  () => _compactCards = v,
                ),
              ),
              const SizedBox(height: 18),
              _note(
                'These preferences are stored locally. They do not enable Android notifications, change GPS permissions, or turn location sharing on or off.',
              ),
              const SizedBox(height: 14),
              _actionTile(
                Icons.location_on_outlined,
                'Review location permission',
                'Use Android Settings to review SAFEFAMILY permissions.',
                () => _showInfo(
                  'Location permission',
                  'Open Android Settings > Apps > SAFEFAMILY > Permissions > Location. Choose the permission level you are comfortable with. This screen does not change the permission automatically.',
                ),
              ),
              _actionTile(
                Icons.notifications_outlined,
                'Notification status',
                'Check whether alerts are configured.',
                () => _showInfo(
                  'Notifications',
                  'Notification delivery is not activated by the preference above. Android notification permission and a notification delivery service must be configured and tested separately.',
                ),
              ),
            ],
          ),
  );

  Widget _switchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      activeThumbColor: _green,
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: _muted, fontSize: 11, height: 1.4),
      ),
    ),
  );

  Widget _actionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: ListTile(
      leading: Icon(icon, color: _green),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: _muted, fontSize: 11),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );

  Widget _note(String value) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _border),
    ),
    child: Text(
      value,
      style: const TextStyle(color: _muted, fontSize: 12, height: 1.5),
    ),
  );

  void _showInfo(String title, String body) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _UpdatesPage extends _ProfileInfoPage {
  const _UpdatesPage()
    : super(
        title: 'App updates',
        subtitle: 'Version details, release notes and installation guidance.',
        icon: Icons.system_update_alt_rounded,
      );

  @override
  List<Widget> content(BuildContext context) => [
    section(
      'Current version',
      'SAFEFAMILY 1.0.0+1\nThis is the version declared in the current project.',
    ),
    section(
      'Latest version',
      'Not available yet. SAFEFAMILY does not currently have a configured online version manifest or release endpoint, so this app cannot verify whether a newer release exists.',
    ),
    section(
      'Release notes',
      'Current build: profile and account information; family setup; app navigation; existing safety and chat areas. Some features may still be in development. Check the project release notes for confirmed changes before distribution.',
    ),
    section(
      'Check for updates',
      'Automatic update checking is not connected yet. To enable it, publish a version manifest at a stable HTTPS address and compare its version/build number with this app.',
    ),
    section(
      'Update SAFEFAMILY',
      'For a direct APK release, download only from the official trusted distribution address, verify the version, then open the APK and approve Androidâ€™s installation prompt. Android generally requires user confirmation. For a Play Store release, use the supported in-app update flow when eligible.',
    ),
    section(
      'Update notifications',
      'The reminder preference can be saved in Settings, but push notifications are not sent until a notification service and delivery workflow are implemented and tested.',
    ),
  ];
}
