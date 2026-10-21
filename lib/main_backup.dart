
import 'package:flutter/material.dart';

void main() {
  runApp(const SafeFamilyApp());
}

const emerald = Color(0xFF16D9A0);
const background = Color(0xFF0B1110);
const surface = Color(0xFF151F1C);
const muted = Color(0xFF9AAEA5);

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
  bool sosConfirmationShown = false;

  final List<String> tabs = [
    'Home',
    'Family',
    'Safety',
    'Profile',
  ];

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: selectedTab,
          children: [
            buildHome(),
            buildSimplePage(
              Icons.groups_rounded,
              'Your family',
              'Family invitations and shared profiles will be built here.',
            ),
            buildSimplePage(
              Icons.shield_rounded,
              'Safety centre',
              'Safe zones, check-ins and safety alerts will be managed here.',
            ),
            buildSimplePage(
              Icons.person_rounded,
              'Your profile',
              'Your account and privacy settings will be available here.',
            ),
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
                  'Notifications will be available when alerts are implemented.',
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
          const Text(
            'Your people,',
            style: TextStyle(
              fontSize: 29,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'your peace of mind.',
            style: TextStyle(
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
              border: Border.all(color: emerald.withValues(alpha: 0.22)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: emerald,
                      size: 22,
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'SAFETY OVERVIEW',
                        style: TextStyle(
                          letterSpacing: 1.1,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30463D),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'PREVIEW',
                        style: TextStyle(
                          color: emerald,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Build your family safety circle',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Set up your family before enabling location sharing and alerts.',
                  style: TextStyle(
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
                    onPressed: () {
                      setState(() => selectedTab = 1);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: emerald,
                      foregroundColor: background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Set up my family',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Add members'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF254238),
                  child: Icon(
                    Icons.people_alt_rounded,
                    color: emerald,
                  ),
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No family members yet',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Your invited members will appear here.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: muted),
              ],
            ),
          ),
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
                color: const Color(0xFFFF6675).withValues(alpha: 0.25),
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
                  'Emergency messaging is not active yet. This preview will not contact emergency services.',
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
                            'Emergency messaging has not been connected yet. No alert or SMS has been sent.',
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
                      backgroundColor: const Color(0xFFFF6675),
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

  Widget buildSimplePage(
    IconData icon,
    String title,
    String description,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'UNDER DEVELOPMENT',
              style: TextStyle(
                color: emerald,
                letterSpacing: 1.4,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
