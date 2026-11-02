import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

const Color _emerald = Color(0xFF16D9A0);
const Color _background = Color(0xFF0B1110);
const Color _muted = Color(0xFF9AAEA5);

class AuthGate extends StatelessWidget {
  final WidgetBuilder authenticatedBuilder;
  final Stream<User?>? authStateChanges;

  const AuthGate({
    super.key,
    required this.authenticatedBuilder,
    this.authStateChanges,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateChanges ?? FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: _background,
            body: Center(child: CircularProgressIndicator(color: _emerald)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: _background,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to check your sign-in status.\n'
                  'Check your internet connection and try again.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        }

        if (snapshot.data != null) {
          return authenticatedBuilder(context);
        }

        return const AuthenticationPage();
      },
    );
  }
}

class AuthenticationPage extends StatefulWidget {
  const AuthenticationPage({super.key});

  @override
  State<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  bool _busy = false;

  static final Future<void> _googleSignInInitialization = GoogleSignIn.instance
      .initialize(
        serverClientId: '89374348217-lk2fr9jm3ua5lec3orraqla4e2u4fri3.apps.googleusercontent.com',
      );

  Future<void> _signInWithGoogle() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await _googleSignInInitialization;

      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw StateError(
          'Google did not return an ID token. Check the Firebase '
          'and Google sign-in configuration.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      await FirebaseAuth.instance.signInWithCredential(credential);

      // AuthGate observes Firebase authStateChanges and opens the dashboard.
    } on GoogleSignInException catch (error) {
      if (error.code.name != 'canceled' && mounted) {
        _showMessage(
          'Google sign-in failed: '
          '${error.description ?? error.code.name}',
        );
      }
      debugPrint('Google sign-in error: $error');
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        switch (error.code) {
          case 'account-exists-with-different-credential':
            _showMessage(
              'An account already exists with this email using another '
              'sign-in method. Contact support to link your account safely.',
            );
          case 'network-request-failed':
            _showMessage('Check your internet connection and try again.');
          case 'operation-not-allowed':
            _showMessage(
              'Google sign-in is not enabled in the Firebase project.',
            );
          case 'too-many-requests':
            _showMessage('Too many attempts. Please wait and try again.');
          default:
            _showMessage(
              error.message ?? 'Unable to sign in with Google. Try again.',
            );
        }
      }
      debugPrint('Firebase authentication error: $error');
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Google sign-in could not be completed. Check your connection '
          'and try again.',
        );
      }
      debugPrint('Google sign-in error: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.shield_moon_rounded,
                    color: _emerald,
                    size: 76,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SAFEFAMILY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _emerald,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Family safety, even without internet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 14),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Your family. Your safety.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Continue securely with your Google account. '
                    'No separate SAFEFAMILY password is needed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _signInWithGoogle,
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _emerald,
                              ),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(
                        _busy ? 'Connecting to Google...' : 'Sign In',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF293831)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _signInWithGoogle,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _emerald,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Your Google account identifies you. '
                    'You can set up or join your family after signing in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
