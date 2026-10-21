
import 'package:flutter/material.dart';
import 'chat_page.dart';

void main() {
  runApp(const SafeFamilyApp());
}

const emerald = Color(0xFF16D9A0);
const background = Color(0xFF0B1110);
const surface = Color(0xFF151F1C);
const muted = Color(0xFF9AAEA5);
const danger = Color(0xFFFF6675);

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
}

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
      ),
      home: const SafetyDashboard(),
    );
  }
}

class SafetyDashboard extends StatefulWidget {
  const SafetyDashboard({super.key});

  @override
  State<SafetyDashboard> createState() => _SafetyDashboardState();
}

class _SafetyDashboardState extends State<SafetyDashboard> {
  int selectedTab = 0;
  FamilyProfile? family;

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> openFamilySetup() async {
    final result = await Navigator.push<FamilyProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => FamilySetupPage(existingFamily: family),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        family = result;
        selectedTab = 0;
      });

      showMessage('Family profile created on this device.');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: () => showMessage(
                  'Real notifications have not been connected yet.',
                ),
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
            family?.guardianName.split(' ').first ??
                'your peace of mind.',
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
            style: TextStyle(
              color: muted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 25),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF183E32), Color(0xFF14251F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: emerald.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      color: emerald,
                      size: 22,
                    ),
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
                    StatusPill(label: 'SETUP'),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  family == null
                      ? 'Build your family safety circle'
                      : family!.familyName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  family == null
                      ? 'Create your family profile to begin setting up your safety circle.'
                      : 'Your family profile is ready. Member invitations and live safety services are the next steps.',
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
                      family == null
                          ? 'Set up my family'
                          : 'Edit family details',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                onPressed: () => setState(() => selectedTab = 1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                label: const Text('View family'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (family == null)
            emptyFamilyCard()
          else
            familySummaryCard(),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF28191B),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: danger.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.sos_rounded,
                  size: 42,
                  color: Color(0xFFFF7883),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Need help?',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'SOS messaging is not connected yet. This preview does not contact emergency services or send SMS.',
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
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('SOS preview'),
                          content: const Text(
                            'No emergency alert or SMS has been sent. Emergency messaging must be implemented and tested before use.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext),
                              child: const Text('Understood'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.warning_amber_rounded),
                    label: const Text(
                      'Emergency SOS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
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
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              'SAFETY • TRUST • FAMILY',
              style: TextStyle(
                color: muted,
                fontSize: 10,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget emptyFamilyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
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
                  'Set up your family to get started.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: muted),
        ],
      ),
    );
  }

  Widget familySummaryCard() {
    final currentFamily = family!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: emerald.withValues(alpha: 0.18),
        ),
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
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: emerald),
        ],
      ),
    );
  }

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
            'Manage your family profile and prepare to invite trusted members.',
            style: TextStyle(color: muted, height: 1.5),
          ),
          const SizedBox(height: 25),
          if (family == null) ...[
            emptyFamilyCard(),
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
            familySummaryCard(),
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
            const Text(
              'FAMILY MEMBERS',
              style: TextStyle(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.person_add_alt_1_rounded,
                    size: 35,
                    color: emerald,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No members invited yet',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Member invitations are the next development step. No invitation has been sent.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          const InfoNote(
            text:
                'This profile is currently stored in app memory only. It will not survive closing the app or restarting the phone yet.',
          ),
        ],
      ),
    );
  }

  Widget buildSafetyPage() {
    return const FeaturePlaceholder(
      icon: Icons.shield_rounded,
      title: 'Safety centre',
      description:
          'This is where location sharing, safe zones, check-ins and safety alerts will be managed.',
      items: [
        'GPS location and last-known position',
        'Safe-zone entry and exit alerts',
        'Missed check-ins',
        'Emergency contacts and SOS delivery',
      ],
    );
  }

  Widget buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Text(
            'Your profile',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (family == null)
            const InfoNote(
              text: 'Create a family profile to see the guardian details here.',
            )
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: Color(0xFF254238),
                    child: Icon(
                      Icons.person_rounded,
                      color: emerald,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    family!.guardianName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Guardian profile · Local preview',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const Divider(height: 30),
                  ProfileDetail(
                    label: 'Family',
                    value: family!.familyName,
                  ),
                  ProfileDetail(
                    label: 'Phone',
                    value: family!.phone,
                  ),
                  ProfileDetail(
                    label: 'City / area',
                    value: family!.city,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: openFamilySetup,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit details'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const InfoNote(
            text:
                'Account login, password recovery, privacy controls and secure cloud synchronisation have not been implemented yet.',
          ),
        ],
      ),
    );
  }
}

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
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    if (value.trim().length < 2) {
      return 'Please enter at least 2 characters.';
    }
    return null;
  }

  String? validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Enter a contact phone number.';
    }

    final digits = phone.replaceAll(RegExp(r'[\s()+-]'), '');

    if (!RegExp(r'^\d{10,15}$').hasMatch(digits)) {
      return 'Enter a valid phone number with 10–15 digits.';
    }

    return null;
  }

  void saveFamily() {
    if (!formKey.currentState!.validate()) return;

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
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingFamily == null
              ? 'Create your family'
              : 'Edit family details',
        ),
        backgroundColor: background,
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
              const Text(
                'Start with your family',
                style: TextStyle(
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
                decoration: fieldDecoration(
                  label: 'City or area',
                  icon: Icons.location_on_outlined,
                  hint: 'e.g. Kaduna North',
                ),
                validator: validateRequired,
              ),
              const SizedBox(height: 22),
              const InfoNote(
                text:
                    'Prototype notice: these details are held in memory while the app is running. This screen does not create an online account or invite family members.',
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: saveFamily,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    widget.existingFamily == null
                        ? 'Create family profile'
                        : 'Save changes',
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
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: emerald,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: muted,
                fontSize: 12,
                height: 1.55,
              ),
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

  const ProfileDetail({
    super.key,
    required this.label,
    required this.value,
  });

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
            style: const TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: muted, height: 1.6),
          ),
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
                    child: Text(
                      item,
                      style: const TextStyle(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          const InfoNote(
            text:
                'These features are not active yet. We will implement and test them before describing them as working safety services.',
          ),
        ],
      ),
    );
  }
}
