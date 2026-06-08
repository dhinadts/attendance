import 'package:attendance/screens/privacy_policy_screen.dart';
import 'package:attendance/screens/support_screen.dart';
import 'package:attendance/screens/terms_conditions_screen.dart';
import 'package:attendance/widgets/primary_action_button.dart';
import 'package:attendance/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('primary action button handles taps', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryActionButton(
            label: 'LOGIN',
            icon: Icons.login,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('LOGIN'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('status chip renders alert label and icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusChip(
            label: 'Login required',
            type: StatusChipType.alert,
            icon: Icons.error_outline,
          ),
        ),
      ),
    );

    expect(find.text('LOGIN REQUIRED'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('mobile support and legal screens render without overflow', (
    tester,
  ) async {
    await _setMobileViewport(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMobileScreen(tester, const SupportScreen());
    _expectNoFlutterOverflow(tester);

    await _pumpMobileScreen(tester, const PrivacyPolicyScreen());
    _expectNoFlutterOverflow(tester);

    await _pumpMobileScreen(tester, const TermsConditionsScreen());
    _expectNoFlutterOverflow(tester);
  });
}

Future<void> _setMobileViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
}

Future<void> _pumpMobileScreen(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pump();
}

void _expectNoFlutterOverflow(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception == null) return;
  final text = exception.toString();
  expect(text, isNot(contains('RenderFlex overflowed')));
  expect(text, isNot(contains('overflowed by')));
  throw exception;
}
