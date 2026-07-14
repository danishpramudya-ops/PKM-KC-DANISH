// Smoke test dasar: pastikan AnchorpulseApp bisa dibangun dan membuka
// ConnectScreen tanpa error, tanpa perlu perangkat BLE asli.

import 'package:flutter_test/flutter_test.dart';

import 'package:anchorpulse/presentation/app.dart';

void main() {
  testWidgets('AnchorpulseApp menampilkan layar connect', (WidgetTester tester) async {
    await tester.pumpWidget(const AnchorpulseApp());

    expect(find.text('POINTRESCUE'), findsOneWidget);
    expect(find.text('Mulai Pindai'), findsOneWidget);
  });
}
