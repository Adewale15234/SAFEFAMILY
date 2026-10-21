
import 'package:flutter_test/flutter_test.dart';
import 'package:safefamily/main.dart';

void main() {
  testWidgets('SAFEFAMILY welcome screen displays', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SafeFamilyApp());

    expect(find.text('SAFEFAMILY'), findsOneWidget);
    expect(find.text('Set up my family'), findsOneWidget);
  });
}
