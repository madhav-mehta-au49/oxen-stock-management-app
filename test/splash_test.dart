import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oxen_solar_stock/features/splash/splash_screen.dart';
import 'package:oxen_solar_stock/features/splash/startup_gate.dart';

void main() {
  Widget app(Future<void> Function() initialize) => MaterialApp(
    home: StartupGate(
      initialize: initialize,
      child: const Scaffold(body: Text('Workspace ready')),
    ),
  );

  testWidgets('fast initialization cannot skip the splash entrance', (
    tester,
  ) async {
    await tester.pumpWidget(app(() async {}));
    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2199));
    expect(find.text('Workspace ready'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Workspace ready'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('slow initialization stays on splash until it completes', (
    tester,
  ) async {
    final initialized = Completer<void>();
    await tester.pumpWidget(app(() => initialized.future));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Workspace ready'), findsNothing);
    initialized.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Workspace ready'), findsOneWidget);
  });

  testWidgets('initialization failure offers a working retry', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      app(() async {
        if (++attempts == 1) throw StateError('Initialization failed');
      }),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Workspace ready'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(attempts, 2);
    expect(find.text('Workspace ready'), findsOneWidget);
  });

  testWidgets('completion after disposal is safe', (tester) async {
    final initialized = Completer<void>();
    await tester.pumpWidget(app(() => initialized.future));
    await tester.pumpWidget(const SizedBox());
    initialized.complete();
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 640), const Size(844, 390)]) {
    testWidgets('splash fits $size with large text and reduced motion', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              disableAnimations: true,
              textScaler: const TextScaler.linear(2),
            ),
            child: const SplashScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Oxen Energies'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
