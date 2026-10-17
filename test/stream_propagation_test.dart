import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:oxen_solar_stock/core/theme/app_theme.dart';
import 'package:oxen_solar_stock/features/dashboard/dashboard_screen.dart';
import 'package:oxen_solar_stock/features/stock/stock_list_screen.dart';
import 'package:oxen_solar_stock/models/app_notification.dart';
import 'package:oxen_solar_stock/models/challan.dart';
import 'package:oxen_solar_stock/models/stock_item.dart';
import 'package:oxen_solar_stock/models/stock_transaction.dart';
import 'package:oxen_solar_stock/providers/auth_providers.dart';
import 'package:oxen_solar_stock/providers/notification_providers.dart';
import 'package:oxen_solar_stock/providers/stock_providers.dart';

StockItem _sample() => StockItem(
      id: 'ITM-NEW',
      name: 'Test Panel 330W',
      category: ItemCategory.solarPvModules,
      sku: 'OX-TEST-NEW',
      unit: 'Unit',
      quantity: 25,
      reorderLevel: 5,
      purchasePrice: 8000,
      sellingPrice: 9500,
      supplier: 'SunRay',
      glyphKey: 'panel',
      createdAt: DateTime.now(),
    );

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget home,
      StreamController<List<StockItem>> items) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream<User?>.value(null)),
          itemsStreamProvider.overrideWith((ref) => items.stream),
          transactionsStreamProvider
              .overrideWith((ref) => Stream.value(const <StockTransaction>[])),
          challansStreamProvider
              .overrideWith((ref) => Stream.value(const <Challan>[])),
          notificationsProvider
              .overrideWith((ref) => Stream.value(const <AppNotification>[])),
          notificationsSeenAtProvider
              .overrideWith((ref) => Stream<DateTime?>.value(null)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: home),
      ),
    );
  }

  testWidgets('Stock list reflects stream emissions', (tester) async {
    final items = StreamController<List<StockItem>>.broadcast();
    addTearDown(items.close);

    await pump(tester, const StockListScreen(), items);
    items.add(const <StockItem>[]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    items.add([_sample()]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('Test Panel 330W'), findsOneWidget);
  });

  testWidgets('Dashboard reflects stream emissions', (tester) async {
    final items = StreamController<List<StockItem>>.broadcast();
    addTearDown(items.close);

    await pump(tester, DashboardScreen(onNavigate: (_) {}), items);
    items.add(const <StockItem>[]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    items.add([_sample()]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // "1" total items should now appear in the mini-stat.
    expect(find.text('1'), findsWidgets);
  });
}
