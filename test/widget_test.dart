import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heartech/core/theme/app_theme.dart';

void main() {
  testWidgets('HearTech theme smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(
                'HearTech',
                style: TextStyle(color: HearTechColors.deepTeal),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('HearTech'), findsOneWidget);
  });
}
