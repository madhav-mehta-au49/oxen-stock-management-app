import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oxen_solar_stock/core/theme/app_theme.dart';
import 'package:oxen_solar_stock/models/app_notification.dart';
import 'package:oxen_solar_stock/models/challan.dart';
import 'package:oxen_solar_stock/models/stock_item.dart';
import 'package:oxen_solar_stock/models/stock_transaction.dart';
import 'package:oxen_solar_stock/providers/auth_providers.dart';
import 'package:oxen_solar_stock/providers/notification_providers.dart';
import 'package:oxen_solar_stock/providers/stock_providers.dart';
import 'package:oxen_solar_stock/features/auth/login_screen.dart';
import 'package:oxen_solar_stock/features/challan/challan_form_screen.dart';
import 'package:oxen_solar_stock/features/challan/challan_list_screen.dart';
import 'package:oxen_solar_stock/features/challan/challan_preview_screen.dart';
import 'package:oxen_solar_stock/features/dashboard/dashboard_screen.dart';
import 'package:oxen_solar_stock/features/settings/settings_screen.dart';
import 'package:oxen_solar_stock/features/stock/item_detail_screen.dart';
import 'package:oxen_solar_stock/features/stock/item_form_screen.dart';
import 'package:oxen_solar_stock/features/stock/movement_screen.dart';
import 'package:oxen_solar_stock/features/stock/stock_list_screen.dart';

/// Renders every screen at common phone widths and fails on any layout
/// exception (RenderFlex overflow, unbounded constraints, etc.).
void main() {
  // Never hit the network for fonts inside tests.
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final widths = <double>[320, 360, 411];

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required double width,
    double height = 780,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final captured = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = captured.add;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Backend is not available in tests — stub auth + data streams.
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          itemsStreamProvider.overrideWith(
            (ref) => Stream.value(const <StockItem>[]),
          ),
          transactionsStreamProvider.overrideWith(
            (ref) => Stream.value(const <StockTransaction>[]),
          ),
          challansStreamProvider.overrideWith(
            (ref) => Stream.value(const <Challan>[]),
          ),
          notificationsProvider.overrideWith(
            (ref) => Stream.value(const <AppNotification>[]),
          ),
          notificationsSeenAtProvider.overrideWith(
            (ref) => Stream<DateTime?>.value(null),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: screen),
      ),
    );
    // Let animations / charts settle.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    FlutterError.onError = previous;

    final overflows = captured
        .where((d) => d.exceptionAsString().contains('overflowed'))
        .toList();
    if (overflows.isNotEmpty) {
      // ignore: avoid_print
      print('LAYOUT ERROR on ${screen.runtimeType} @${width}px');
      for (final d in overflows) {
        // ignore: avoid_print
        print('DETAIL>>> ${d.toString()}');
      }
    }

    expect(
      overflows,
      isEmpty,
      reason: 'Layout overflow on ${screen.runtimeType} at ${width}px',
    );
  }

  final year = DateTime.now().year;

  final screens = <String, Widget Function()>{
    'Login': () => const LoginScreen(),
    'Dashboard': () => DashboardScreen(onNavigate: (_) {}),
    'StockList': () => const StockListScreen(),
    'ItemForm': () => const ItemFormScreen(),
    'MovementIn': () => const MovementScreen(isIn: true),
    'MovementOut': () => const MovementScreen(isIn: false),
    'ItemDetail': () => const ItemDetailScreen(itemId: 'ITM-001'),
    'ChallanList': () => const ChallanListScreen(),
    'ChallanForm': () => const ChallanFormScreen(),
    'ChallanPreview': () => ChallanPreviewScreen(number: 'OX/CH/$year/0001'),
    'Settings': () => const SettingsScreen(),
  };

  for (final width in widths) {
    screens.forEach((name, build) {
      testWidgets('$name renders at ${width.toInt()}px', (tester) async {
        await pumpScreen(tester, build(), width: width);
      });
    });
  }
}
