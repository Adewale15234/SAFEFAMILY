
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
            body: Center(
              child: CircularProgressIndicator(color: _emerald),
            ),
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
  String? _busyAction;

  static final Future<void> _googleSignInInitialization =
      GoogleSignIn.instance.initialize();

  Future<void> _authenticateWithGoogle({
    required bool isSignUp,
  }) async {
    if (_busyAction != null) return;

    setState(() {
      _busyAction = isSignUp ? 'signup' : 'signin';
    });

    try {
      await _googleSignInInitialization;

      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw StateError(
          'Google did not return an ID token. Check the Android '
          'signing fingerprints and Google OAuth configuration.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      debugPrint(
        'SAFEFAMILY authentication successful. '
        'New Firebase account: ${result.additionalUserInfo?.isNewUser}',
      );

      // AuthGate observes authStateChanges and opens the dashboard.
    } on GoogleSignInException catch (error) {
      debugPrint('Google sign-in error: $error');

      if (mounted && error.code.name != 'canceled') {
        _showMessage(
          'Google sign-in failed: '
          '${error.description ?? error.code.name}',
        );
      }
    } on FirebaseAuthException catch (error) {
      debugPrint('Firebase authentication error: $error');

      if (!mounted) return;

      switch (error.code) {
        case 'account-exists-with-different-credential':
          _showMessage(
            'An account already exists with this email using another '
            'sign-in method. Contact support to link it safely.',
          );
          break;
        case 'network-request-failed':
          _showMessage(
            'No network connection. Connect to the internet and try again.',
          );
          break;
        case 'operation-not-allowed':
          _showMessage(
            'Google sign-in is disabled in Firebase Authentication.',
          );
          break;
        case 'too-many-requests':
          _showMessage(
            'Too many attempts. Please wait and try again.',
          );
          break;
        case 'invalid-credential':
          _showMessage(
            'Google returned an invalid credential. Check the Firebase '
            'and Google OAuth configuration.',
          );
          break;
        default:
          _showMessage(
            'Firebase sign-in failed (${error.code}): '
            '${error.message ?? 'Please try again.'}',
          );
      }
    } catch (error, stackTrace) {
      debugPrint('SAFEFAMILY Google authentication error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage(
          'Could not complete Google authentication. '
          'Please try again. Details: $error',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busyAction = null);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Widget _googleButton({
    required String label,
    required String action,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    final isBusy = _busyAction != null;
    final isThisActionBusy = _busyAction == action;

    return SizedBox(
      height: 54,
      child: primary
          ? ElevatedButton.icon(
              onPressed: isBusy ? null : onPressed,
              icon: isThisActionBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _background,
                      ),
                    )
                  : const Icon(Icons.g_mobiledata_rounded, size: 32),
              label: Text(
                isThisActionBusy ? 'Connecting to Google...' : label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _emerald,
                foregroundColor: _background,
                disabledBackgroundColor: _emerald.withValues(alpha: 0.5),
                disabledForegroundColor: _background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: isBusy ? null : onPressed,
              icon: isThisActionBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _emerald,
                      ),
                    )
                  : const Icon(Icons.g_mobiledata_rounded, size: 32),
              label: Text(
                isThisActionBusy ? 'Connecting to Google...' : label,
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
    );
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
                    'Choose how you want to continue. '
                    'Both options use your Google account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _googleButton(
                    label: 'Sign in with Google',
                    action: 'signin',
                    onPressed: () => _authenticateWithGoogle(
                      isSignUp: false,
                    ),
                    primary: true,
                  ),
                  const SizedBox(height: 14),
                  _googleButton(
                    label: 'Sign up with Google',
                    action: 'signup',
                    onPressed: () => _authenticateWithGoogle(
                      isSignUp: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'New to SAFEFAMILY? Choose Sign up. '
                    'Already using SAFEFAMILY? Choose Sign in.\n\n'
                    'Google verifies your identity. Firebase creates your '
                    'account the first time you successfully authenticate. '
                    'You can set up or join your family after signing in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
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
