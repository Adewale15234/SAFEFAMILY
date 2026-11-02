import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safefamily/auth_gate.dart';

void main() {
  testWidgets('SAFEFAMILY offers Google-only authentication when signed out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authStateChanges: Stream<User?>.value(null),
          authenticatedBuilder: (_) =>
              const Scaffold(body: Text('Authenticated dashboard')),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(AuthenticationPage), findsOneWidget);
    expect(find.text('SAFEFAMILY'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);

    // The old email/password registration form must not return.
    expect(find.text('Create your account'), findsNothing);
    expect(find.text('Create account'), findsNothing);
    expect(find.text('Full name'), findsNothing);
    expect(find.text('Email address'), findsNothing);
    expect(find.text('Password'), findsNothing);
    expect(find.text('Forgot password?'), findsNothing);
  });
}
