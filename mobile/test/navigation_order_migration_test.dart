import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novelai_mobile/main.dart' show HomeShell;
import 'package:novelai_mobile/state/app_state.dart';
import 'package:novelai_mobile/ui/studio_shell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<int>?> _restoredOrder(
    WidgetTester tester, Map<String, Object> preferences) async {
  SharedPreferences.setMockInitialValues(preferences);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final state = AppState()
    ..booted = true
    ..needsNetworkOnboarding = false;
  addTearDown(state.dispose);
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state, child: const MaterialApp(home: HomeShell())));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final order = tester
      .widget<StudioAdaptiveShell>(find.byType(StudioAdaptiveShell))
      .destinationOrder;
  await tester.pumpWidget(const SizedBox.shrink());
  return order;
}

void main() {
  testWidgets('an order saved with the removed image agent page drops it',
      (tester) async {
    // Version 1 numbering: 9 was the image agent, the pages after it move up.
    final order = await _restoredOrder(tester, {
      'mobile_navigation_order_v1': ['13', '9', '0', '10', '14'],
    });
    expect(order, hasLength(14));
    expect(order!.take(4), [12, 0, 9, 13]);
  });

  testWidgets('the current order takes precedence over the legacy one',
      (tester) async {
    final order = await _restoredOrder(tester, {
      'mobile_navigation_order_v1': ['13', '9', '0'],
      'mobile_navigation_order_v2': ['3', '2', '1'],
    });
    expect(order!.take(3), [3, 2, 1]);
  });
}
