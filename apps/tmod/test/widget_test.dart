// Basic widget test for SaViCamApp.

import 'package:flutter_test/flutter_test.dart';
import 'package:savicam_t_mod/app.dart';

void main() {
  testWidgets('App landing screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SaViCamApp());
    await tester.pumpAndSettle();

    // Verify that the first mode is 'Trợ lý an toàn'.
    expect(find.text('Trợ lý an toàn'), findsWidgets);
  });
}
