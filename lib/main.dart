import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'location_map_page.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'profile_hub_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'auth_gate.dart';
import 'chat_page.dart';
import 'firebase_options.dart';
import 'family_members.dart';
import 'cloud_family_members.dart';
import 'family_repository.dart';
import 'family_invitations_page.dart';
import 'emergency_service.dart';
import 'sos_notification_service.dart';
import 'emergency_alarm_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // DEVELOPMENT TESTING ONLY: start signed out every time.
  await FirebaseAuth.instance.signOut();

  runApp(const SafeFamilyApp());
}

// -----------------------------------------------------------------------------
// APP THEME
// -----------------------------------------------------------------------------

const emerald = Color(0xFF16D9A0);
const background = Color(0xFF0B1110);
const surface = Color(0xFF151F1C);
const muted = Color(0xFF9AAEA5);
const danger = Color(0xFFFF6675);
const cardBorder = Color(0xFF293831);

// -----------------------------------------------------------------------------
// FAMILY PROFILE MODEL
// -----------------------------------------------------------------------------

class FamilyProfile {
  final String familyName;
  final String guardianName;
  final String phone;
  final String city;

  const FamilyProfile({
    required this.familyName,
    required this.guardianName,
    required this.phone,
    required this.city,
  });

  Map<String, dynamic> toJson() {
    return {
      'familyName': familyName,
      'guardianName': guardianName,
      'phone': phone,
      'city': city,
    };
  }

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    return FamilyProfile(
      familyName: json['familyName'] as String? ?? '',
      guardianName: json['guardianName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
    );
  }
}

// -----------------------------------------------------------------------------
// APP
// -----------------------------------------------------------------------------

class SafeFamilyApp extends StatelessWidget {
  const SafeFamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SAFEFAMILY',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
      ),
      home: AuthGate(authenticatedBuilder: (_) => const SafetyDashboard()),
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN DASHBOARD
// -----------------------------------------------------------------------------

class SafetyDashboard extends StatefulWidget {
  const SafetyDashboard({super.key});

  @override
  State<SafetyDashboard> createState() => _SafetyDashboardState();
}

class _SafetyDashboardState extends State<SafetyDashboard>
    with WidgetsBindingObserver {
  static const String _legacyFamilyStorageKey = 'safefamily_family_profile_v1';

  String get _familyStorageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return 'safefamily_family_profile_v2_${uid ?? 'local'}';
  }

  int selectedTab = 0;
  FamilyProfile? family;
  String? cloudFamilyId;
  bool isLoadingFamily = true;
  bool isSavingFamily = false;
  bool isSendingSos = false;
  bool _isRetryingPendingSos = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(SosNotificationService.instance.initialize());
    _loadFamilyProfile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retryPendingSos();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadFamilyProfile() async {
    FamilyProfile? localProfile;

    try {
      final preferences = await SharedPreferences.getInstance();
      var savedProfile = preferences.getString(_familyStorageKey);

      // Preserve the legacy profile unless the account-specific copy succeeds.
      if (savedProfile == null && FirebaseAuth.instance.currentUser != null) {
        final legacyProfile = preferences.getString(_legacyFamilyStorageKey);

        if (legacyProfile != null) {
          final copied = await preferences.setString(
            _familyStorageKey,
            legacyProfile,
          );

          if (copied) {
            savedProfile = legacyProfile;
            await preferences.remove(_legacyFamilyStorageKey);
          }
        }
      }

      if (savedProfile != null) {
        final decoded = jsonDecode(savedProfile);

        if (decoded is Map<String, dynamic>) {
          localProfile = FamilyProfile.fromJson(decoded);
        } else if (decoded is Map) {
          localProfile = FamilyProfile.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
    } catch (error) {
      debugPrint('Could not load local family profile: $error');
    }

    FamilyProfile? loadedProfile = localProfile;
    final currentUser = FirebaseAuth.instance.currentUser;

    // A cloud profile takes precedence only when this account has a valid
    // active family membership. Local data remains untouched as a fallback.
    if (currentUser != null) {
      try {
        final cloudData = await FamilyRepository().getMyFamily();

        if (cloudData != null) {
          final id = cloudData['familyId'];
          if (id is String && id.isNotEmpty) {
            cloudFamilyId = id;
            loadedProfile = FamilyProfile(
              familyName: cloudData['familyName'] as String? ?? '',
              guardianName: cloudData['guardianName'] as String? ?? '',
              phone: cloudData['phone'] as String? ?? '',
              city: cloudData['city'] as String? ?? '',
            );
          }
        }
      } catch (error) {
        // For example, live Firestore rules may not yet be deployed.
        // Keep the locally saved profile available.
        debugPrint('Could not load cloud family profile: $error');
      }
    }

    if (!mounted) return;

    setState(() {
      family = loadedProfile;
      isLoadingFamily = false;
    });

    final activeFamilyId = cloudFamilyId;

    if (activeFamilyId != null && activeFamilyId.isNotEmpty) {
      unawaited(
        SosNotificationService.instance.listenToFamilySos(activeFamilyId),
      );
    }

    _retryPendingSos();
  }

  Future<void> _retryPendingSos() async {
    if (_isRetryingPendingSos || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final familyId = cloudFamilyId;

    if (user == null || familyId == null || familyId.isEmpty) return;

    _isRetryingPendingSos = true;

    try {
      final delivered = await EmergencyService().retryPendingSos(
        familyId: familyId,
      );

      if (delivered > 0 && mounted) {
        showMessage(
          '$delivered pending SOS alert(s) uploaded to the family record. '
          'Other phones have not been notified yet.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Pending SOS retry failed: $error\n$stackTrace');
    } finally {
      _isRetryingPendingSos = false;
    }
  }

  Future<bool> _persistFamilyProfile(FamilyProfile profile) async {
    try {
      final preferences = await SharedPreferences.getInstance();

      return await preferences.setString(
        _familyStorageKey,
        jsonEncode(profile.toJson()),
      );
    } catch (error) {
      debugPrint('Could not save family profile locally: $error');
      return false;
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openFamilySetup() async {
    final result = await Navigator.push<FamilyProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => FamilySetupPage(existingFamily: family),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      isSavingFamily = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (cloudFamilyId != null) {
        // Existing cloud family: update cloud first, then refresh local cache.
        await FamilyRepository().updateFamily(
          familyId: cloudFamilyId!,
          familyName: result.familyName,
          guardianName: result.guardianName,
          phone: result.phone,
          city: result.city,
        );

        if (!mounted) return;

        setState(() {
          family = result;
          selectedTab = 0;
        });

        final locallySaved = await _persistFamilyProfile(result);

        if (!mounted) return;
        showMessage(
          locallySaved ? 'Family profile synced with the cloud.' : 'Cloud profile updated, but the local backup could not be saved.',
        );
        return;
      }

      // Without cloud membership, signed-in users choose explicitly.
      var saveToCloud = false;

      if (currentUser != null) {
        final choice = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Where should we save your family?'),
            content: const Text(
              'Your existing local data will be preserved. You can save '
              'this profile on this device or create a cloud family so '
              'membership and invitations can be connected later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'cancel'),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'local'),
                child: const Text('This device only'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, 'cloud'),
                child: const Text('Create cloud family'),
              ),
            ],
          ),
        );

        if (choice == null || choice == 'cancel') return;
        saveToCloud = choice == 'cloud';
      }

      if (saveToCloud) {
        // Repository creates family, owner membership and account index
        // atomically. It rejects accounts that already have an index.
        final createdId = await FamilyRepository().createFamily(
          familyName: result.familyName,
          guardianName: result.guardianName,
          phone: result.phone,
          city: result.city,
        );

        cloudFamilyId = createdId;
      }

      final locallySaved = await _persistFamilyProfile(result);

      if (!mounted) return;

      setState(() {
        family = result;
        selectedTab = 0;
      });

      if (saveToCloud) {
        showMessage(
          locallySaved ? 'Cloud family created successfully.' : 'Cloud family created, but the local backup could not be saved.',
        );
      } else {
        showMessage(
          locallySaved
              ? 'Family profile saved on this device only.'
              : 'The profile could not be saved locally.',
        );
      }
    } catch (error) {
      debugPrint('Could not save family profile: $error');
      if (mounted) {
        showMessage(
          'Family profile was not synced. Check your connection and '
          'Firebase permissions, then try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSavingFamily = false;
        });
      }
    }
  }

  void openFamilyTab() {
    setState(() => selectedTab = 1);
  }

  void openProfileTab() {
    setState(() => selectedTab = 4);
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will return to the sign-in screen. Your family profile '
          'saved on this device will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true || !mounted) return;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (error) {
      if (mounted) {
        showMessage('Could not sign out. Please try again.');
        debugPrint('Sign-out error: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingFamily) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: emerald),
                SizedBox(height: 16),
                Text(
                  'Preparing your family space...',
                  style: TextStyle(color: muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedTab,
          children: [
            buildHome(),
            buildFamilyPage(),
            const FamilyChatPage(),
            buildSafetyPage(),
            buildProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: surface,
        indicatorColor: emerald.withValues(alpha: 0.15),
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: 'Family',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Safety',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HOME
  // ---------------------------------------------------------------------------

  Widget buildHome() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: emerald,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: background,
                  size: 29,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAFEFAMILY',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        fontSize: 17,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'YOUR FAMILY. YOUR PRIORITY.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () =>
                    showMessage('Notifications are not connected yet.'),
                icon: const Icon(Icons.notifications_none_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: surface,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            family == null ? 'Your people,' : 'Welcome,',
            style: const TextStyle(
              fontSize: 29,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            family?.guardianName.split(' ').first ?? 'your peace of mind.',
            style: const TextStyle(
              fontSize: 29,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: emerald,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Stay prepared. Stay connected. Look out for one another.',
            style: TextStyle(color: muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 25),
          _buildSafetyOverviewCard(),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'YOUR FAMILY',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.3,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: openFamilyTab,
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: const Text('View family'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (family == null)
            emptyFamilyCard(onTap: openFamilySetup)
          else
            familySummaryCard(onTap: openFamilyTab),
          const SizedBox(height: 28),
          const Text(
            'EMERGENCY ASSISTANCE',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.3,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildSosCard(),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              'SAFETY - TRUST - FAMILY',
              style: TextStyle(color: muted, fontSize: 10, letterSpacing: 2),
            ),
          ),
          if (isSavingFamily) ...[
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Saving your profile...',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafetyOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF183E32), Color(0xFF14251F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: emerald.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: emerald, size: 22),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'SAFETY OVERVIEW',
                  style: TextStyle(
                    letterSpacing: 1.1,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              StatusPill(label: 'PROTOTYPE'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            family == null
                ? 'Build your family safety circle'
                : family!.familyName,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 7),
          Text(
            family == null
                ? 'Create your family profile to begin setting up your safety circle.'
                : 'Your family profile is connected. Invitations are available; live location sharing is not enabled yet.',
            style: const TextStyle(
              color: Color(0xFFB9CDC3),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 49,
            child: FilledButton(
              onPressed: openFamilySetup,
              style: FilledButton.styleFrom(
                backgroundColor: emerald,
                foregroundColor: background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                family == null ? 'Set up my family' : 'Edit family details',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF28191B),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: danger.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.sos_rounded, size: 42, color: Color(0xFFFF7883)),
          const SizedBox(height: 8),
          const Text(
            'Need help?',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 7),
          const Text(
            'Records an SOS securely for your active family. Other phones are not notified yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD7BFC1),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: isSendingSos ? null : _showSosConfirmation,
              icon: const Icon(Icons.warning_amber_rounded),
              label: Text(
                isSendingSos ? 'Recording SOS...' : 'Emergency SOS',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: const Color(0xFF241013),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _showTestSosNotification,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Test family SOS notification'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EmergencyAlarmPage(),
                  ),
                );
              },
              icon: const Icon(Icons.flashlight_on_rounded),
              label: const Text('Start local alarm'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTestSosNotification() async {
    final user = FirebaseAuth.instance.currentUser;
    final familyId = cloudFamilyId;

    if (user == null) {
      showMessage('Please sign in before testing SOS notifications.');
      return;
    }

    if (familyId == null || familyId.isEmpty) {
      showMessage('Join or create a cloud family before testing SOS.');
      return;
    }

    final accountName = user.displayName?.trim();
    final emailName = user.email?.split('@').first;
    final senderName = accountName != null && accountName.isNotEmpty
        ? accountName
        : (emailName == null || emailName.isEmpty
              ? 'Family member'
              : emailName);

    try {
      await EmergencyService().submitTestSosAlert(
        familyId: familyId,
        senderName: senderName,
      );

      if (!mounted) return;

      showMessage(
        'Test SOS recorded. Check the other family phone while SAFEFAMILY is open.',
      );
    } catch (error, stackTrace) {
      debugPrint('Test SOS failed: $error\n$stackTrace');

      if (!mounted) return;

      showMessage(
        'Test SOS failed. Check the connection and family membership.',
      );
    }
  }

  Future<void> _showSosConfirmation() async {
    if (isSendingSos) return;

    final user = FirebaseAuth.instance.currentUser;
    final familyId = cloudFamilyId;

    if (user == null) {
      showMessage('Please sign in before sending an SOS.');
      return;
    }

    if (familyId == null || familyId.isEmpty) {
      showMessage('Create or join a family before sending an SOS.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: danger, size: 36),
        title: const Text('Record an emergency SOS?'),
        content: const Text(
          'SAFEFAMILY will save this SOS on your device before trying '
          'to upload it. If the connection is unavailable, it can remain '
          'queued for a later retry. This does not contact emergency '
          'services, send an SMS, or notify other phones by itself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => isSendingSos = true);

    try {
      final emailName = user.email?.split('@').first;
      final displayName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (emailName == null || emailName.isEmpty
                ? 'Family member'
                : emailName);

      final result = await EmergencyService().submitSosAlert(
        familyId: familyId,
        senderName: displayName,
      );

      if (!mounted) return;

      if (result.status == SosDeliveryStatus.delivered) {
        showMessage(
          'SOS uploaded to your family record. Other phones have not '
          'been notified yet.',
        );
      } else {
        showMessage(
          'SOS saved on this device. Upload is pending. Reopen SAFEFAMILY '
          'when your connection returns. Other phones have not been '
          'notified yet.',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Could not record SOS: $error\n$stackTrace');

      if (mounted) {
        showMessage(
          'SOS could not be saved or uploaded. Check your family '
          'membership and connection, then try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSendingSos = false);
      }
    }
  }
  // ---------------------------------------------------------------------------
  // FAMILY CARDS
  // ---------------------------------------------------------------------------

  Widget emptyFamilyCard({VoidCallback? onTap}) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF254238),
                child: Icon(Icons.people_alt_rounded, color: emerald),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No family profile yet',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Tap here to set up your family.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget familySummaryCard({VoidCallback? onTap}) {
    final currentFamily = family;

    if (currentFamily == null) {
      return emptyFamilyCard(onTap: onTap);
    }

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: emerald.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFF254238),
                child: Icon(Icons.home_work_rounded, color: emerald),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentFamily.familyName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Guardian: ${currentFamily.guardianName}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currentFamily.city,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap to view family details',
                      style: TextStyle(color: emerald, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: emerald),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FAMILY TAB
  // ---------------------------------------------------------------------------

  Widget buildFamilyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Your family',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage your family profile and family members.',
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 25),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () async {
                final joined = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const FamilyInvitationsPage(),
                  ),
                );
                if (joined == true) {
                  await _loadFamilyProfile();
                }
              },
              icon: const Icon(Icons.mail_outline_rounded),
              label: const Text('Invitations / Join family'),
            ),
          ),
          const SizedBox(height: 18),
          if (family == null) ...[
            emptyFamilyCard(onTap: openFamilySetup),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: openFamilySetup,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create family profile'),
                style: FilledButton.styleFrom(
                  backgroundColor: emerald,
                  foregroundColor: background,
                ),
              ),
            ),
          ] else ...[
            familySummaryCard(onTap: openFamilySetup),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: openFamilySetup,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('Edit family details'),
              ),
            ),
            const SizedBox(height: 25),
            if (cloudFamilyId != null) ...[
              CloudFamilyMembersSection(familyId: cloudFamilyId!),
              const SizedBox(height: 22),
            ],
            const FamilyMembersSection(),
          ],
          const SizedBox(height: 22),
          InfoNote(
            text: cloudFamilyId != null
                ? 'Your family profile is connected to the cloud. '
                      'Connected family accounts are shown above. Live location sharing is not enabled yet.'
                : 'Your existing profile remains on this device until you '
                      'choose to create a cloud family. Family-member syncing '
                      'and invitations are not connected yet.',
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAFETY TAB
  // ---------------------------------------------------------------------------

  Widget buildSafetyPage() {
    return LocationMapPage(familyId: cloudFamilyId);
  }

  // ---------------------------------------------------------------------------
  // PROFILE TAB

  Widget buildProfilePage() {
    final currentFamily = family;
    final currentUser = FirebaseAuth.instance.currentUser;

    return ProfileHubPage(
      currentUser: currentUser,
      guardianName: currentFamily?.guardianName ?? '',
      familyName: currentFamily?.familyName ?? '',
      phone: currentFamily?.phone ?? '',
      city: currentFamily?.city ?? '',
      onEditFamily: openFamilySetup,
      onSignOut: _signOut,
    );
  }
}

// ---------------------------------------------------------------------------
// FAMILY SETUP FORM
// -----------------------------------------------------------------------------

class FamilySetupPage extends StatefulWidget {
  final FamilyProfile? existingFamily;

  const FamilySetupPage({super.key, this.existingFamily});

  @override
  State<FamilySetupPage> createState() => _FamilySetupPageState();
}

class _FamilySetupPageState extends State<FamilySetupPage> {
  final formKey = GlobalKey<FormState>();

  late final TextEditingController familyNameController;
  late final TextEditingController guardianNameController;
  late final TextEditingController phoneController;
  late final TextEditingController cityController;

  @override
  void initState() {
    super.initState();

    familyNameController = TextEditingController(
      text: widget.existingFamily?.familyName ?? '',
    );
    guardianNameController = TextEditingController(
      text: widget.existingFamily?.guardianName ?? '',
    );
    phoneController = TextEditingController(
      text: widget.existingFamily?.phone ?? '',
    );
    cityController = TextEditingController(
      text: widget.existingFamily?.city ?? '',
    );
  }

  @override
  void dispose() {
    familyNameController.dispose();
    guardianNameController.dispose();
    phoneController.dispose();
    cityController.dispose();
    super.dispose();
  }

  String? validateRequired(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'This field is required.';
    }

    if (text.length < 2) {
      return 'Please enter at least 2 characters.';
    }

    return null;
  }

  String? validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Enter a contact phone number.';
    }

    // Allow digits, spaces, plus signs, parentheses and hyphens.
    if (!RegExp(r'^[0-9+\s()\-]+$').hasMatch(phone)) {
      return 'Use only digits and normal phone-number separators.';
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length < 10 || digits.length > 15) {
      return 'Enter a phone number containing 10 to 15 digits.';
    }

    return null;
  }

  void saveFamily() {
    FocusScope.of(context).unfocus();

    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    final result = FamilyProfile(
      familyName: familyNameController.text.trim(),
      guardianName: guardianNameController.text.trim(),
      phone: phoneController.text.trim(),
      city: cityController.text.trim(),
    );

    Navigator.pop(context, result);
  }

  InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: emerald),
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: emerald),
      ),
      errorMaxLines: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingFamily != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit family details' : 'Create your family'),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color: emerald,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEditing ? 'Update your family' : 'Start with your family',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the guardian and family details below. You can edit them later.',
                style: TextStyle(color: muted, height: 1.5),
              ),
              const SizedBox(height: 25),
              TextFormField(
                controller: familyNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.organizationName],
                decoration: fieldDecoration(
                  label: 'Family name',
                  icon: Icons.home_work_outlined,
                  hint: 'e.g. Adewale Family',
                ),
                validator: validateRequired,
              ),
              const SizedBox(height: 17),
              TextFormField(
                controller: guardianNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: fieldDecoration(
                  label: 'Guardian full name',
                  icon: Icons.person_outline_rounded,
                  hint: 'Enter your full name',
                ),
                validator: validateRequired,
              ),
              const SizedBox(height: 17),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: fieldDecoration(
                  label: 'Contact phone number',
                  icon: Icons.phone_outlined,
                  hint: 'e.g. 08012345678',
                ),
                validator: validatePhone,
              ),
              const SizedBox(height: 17),
              TextFormField(
                controller: cityController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: fieldDecoration(
                  label: 'City or area',
                  icon: Icons.location_on_outlined,
                  hint: 'e.g. Kaduna North',
                ),
                validator: validateRequired,
                onFieldSubmitted: (_) => saveFamily(),
              ),
              const SizedBox(height: 22),
              const InfoNote(
                text: 'Your profile will be saved on this device. This form does not create an online account or invite family members.',
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: saveFamily,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    isEditing ? 'Save changes' : 'Create family profile',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: emerald,
                    foregroundColor: background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// REUSABLE UI COMPONENTS
// -----------------------------------------------------------------------------

class StatusPill extends StatelessWidget {
  final String label;

  const StatusPill({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF30463D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: emerald,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class InfoNote extends StatelessWidget {
  final String text;

  const InfoNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF202B27),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: emerald, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: muted, fontSize: 12, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileDetail extends StatelessWidget {
  final String label;
  final String value;

  const ProfileDetail({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class FeaturePlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> items;

  const FeaturePlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: emerald, size: 38),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: const TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(color: muted, height: 1.6)),
          const SizedBox(height: 25),
          const Text(
            'PLANNED SAFETY FEATURES',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_clock_rounded,
                    color: emerald,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item, style: const TextStyle(height: 1.4)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const InfoNote(
            text: 'These features are not active yet. We will implement and test them before describing them as working safety services.',
          ),
        ],
      ),
    );
  }
}
