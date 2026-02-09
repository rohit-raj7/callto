 
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:call_u/main.dart';

void main() {
  testWidgets('App shows splash progress indicator', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ConnectoApp());

    // Splash screen should show a CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
