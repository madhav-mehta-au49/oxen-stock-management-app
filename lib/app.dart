import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/splash/splash_screen.dart';
import 'features/splash/startup_gate.dart';
import 'providers/auth_providers.dart';

class OxenSolarApp extends StatelessWidget {
  const OxenSolarApp({super.key, required this.initialize});

  final Future<void> Function() initialize;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oxen Energies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: StartupGate(initialize: initialize, child: const AuthGate()),
    );
  }
}

/// Routes between the signed-out [LoginScreen] and the signed-in [AppShell]
/// based on Firebase auth state. Shows the branded splash while resolving.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      loading: () => const SplashScreen(),
      error: (_, _) =>
          SplashScreen(onRetry: () => ref.invalidate(authStateProvider)),
      data: (user) => user == null ? const LoginScreen() : const AppShell(),
    );
  }
}
