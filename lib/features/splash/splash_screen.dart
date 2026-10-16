import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Branded splash shown while Firebase auth state resolves.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Spacer(flex: 3),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Image(
                image: AssetImage('assets/brand/oxen_logo.png'),
                height: 60,
                filterQuality: FilterQuality.high,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'STOCK MANAGER',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
            Spacer(flex: 4),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
