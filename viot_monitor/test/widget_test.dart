import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:viot_monitor/app.dart';
import 'package:viot_monitor/core/providers/app_providers.dart';
import 'package:viot_monitor/core/repositories/mock_viot_repository.dart';

void main() {
  testWidgets('app shell renders VIOT Monitor tabs', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          viotRepositoryProvider.overrideWithValue(MockViotRepository()),
        ],
        child: const ViotMonitorApp(),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('VIOT Monitor'), findsOneWidget);
    expect(find.text('WiFi'), findsOneWidget);
    expect(find.text('Analyze'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('MQTT'), findsOneWidget);
    expect(find.text('Config'), findsOneWidget);
  });
}
