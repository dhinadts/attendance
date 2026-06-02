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
}
