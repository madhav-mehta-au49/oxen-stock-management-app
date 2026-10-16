import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The original transparent wordmark, with a quiet solar-energy entrance.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _energy = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool? _reducedMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion == reduced) return;
    _reducedMotion = reduced;
    if (reduced) {
      _entrance.value = 1;
      _energy.stop();
      _energy.value = .5;
    } else {
      _entrance.forward();
      _energy.repeat();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _energy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final retry = widget.onRetry;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: Listenable.merge([_entrance, _energy]),
                builder: (context, _) => CustomPaint(
                  painter: _EnergyLandscape(
                    reveal: Curves.easeOut.transform(_entrance.value),
                    phase: _energy.value,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Short landscape screens scroll instead of clipping text.
                final height = math.max(constraints.maxHeight, 600.0);
                return SingleChildScrollView(
                  child: SizedBox(
                    height: height,
                    child: Stack(
                      children: [
                        Positioned(
                          top: height * .37,
                          left: 32,
                          right: 32,
                          child: AnimatedBuilder(
                            animation: _entrance,
                            builder: (context, child) {
                              final t = Curves.easeOutCubic.transform(
                                (_entrance.value / .8).clamp(0.0, 1.0),
                              );
                              return Opacity(
                                opacity: t,
                                child: Transform.translate(
                                  offset: Offset(0, 18 * (1 - t)),
                                  child: Transform.scale(
                                    scale: .96 + .04 * t,
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: Column(
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 360,
                                  ),
                                  child: Image.asset(
                                    'assets/brand/oxen_logo.png',
                                    semanticLabel: 'Oxen Energies',
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                const Text(
                                  'STOCK MANAGER',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 3.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: height * .69,
                          left: 24,
                          right: 24,
                          child: Column(
                            children: [
                              if (retry == null) ...[
                                Semantics(
                                  label: 'Loading',
                                  child: SizedBox(
                                    width: 96,
                                    height: 3,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: AnimatedBuilder(
                                        animation: _energy,
                                        builder: (context, _) => CustomPaint(
                                          painter: _EnergyLoader(_energy.value),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              Text(
                                retry == null
                                    ? 'Preparing your workspace'
                                    : 'Unable to start. Please try again.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  letterSpacing: .4,
                                ),
                              ),
                              if (retry != null) ...[
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: retry,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Try again'),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Positioned(
                          left: 24,
                          right: 24,
                          bottom: 24,
                          child: Text(
                            'SOLAR EQUIPMENT & EPC SUPPLIES',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

const _energyGradient = LinearGradient(
  colors: [AppColors.primary, AppColors.accent, AppColors.accentBright],
);

class _EnergyLoader extends CustomPainter {
  const _EnergyLoader(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE9EEF1),
    );
    final x = -42 + (size.width + 42) * phase;
    final segment = Rect.fromLTWH(x, 0, 42, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(segment, const Radius.circular(3)),
      Paint()..shader = _energyGradient.createShader(segment),
    );
  }

  @override
  bool shouldRepaint(_EnergyLoader oldDelegate) => phase != oldDelegate.phase;
}

class _EnergyLandscape extends CustomPainter {
  const _EnergyLandscape({required this.reveal, required this.phase});
  final double reveal;
  final double phase;

  Path _curve(Size size, double shift) => Path()
    ..moveTo(-20, 100 + shift)
    ..cubicTo(
      size.width * .27,
      178 + shift,
      size.width * .40,
      170 + shift,
      size.width * .61,
      76 + shift,
    )
    ..cubicTo(
      size.width * .84,
      -8 + shift,
      size.width * .96,
      24 + shift,
      size.width + 30,
      70 + shift,
    );

  @override
  void paint(Canvas canvas, Size size) {
    final area = _curve(size, 12)
      ..lineTo(size.width + 30, size.height)
      ..lineTo(-20, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: .035 * reveal),
            AppColors.accentBright.withValues(alpha: .07 * reveal),
          ],
        ).createShader(Offset.zero & size),
    );
    for (final shift in [0.0, 32.0]) {
      final metric = _curve(size, shift).computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * reveal),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = shift == 0 ? 1 : .7
          ..shader = LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: .18),
              AppColors.accentBright.withValues(alpha: .18),
            ],
          ).createShader(Offset.zero & size),
      );
      if (shift == 0) {
        final tangent = metric.getTangentForOffset(metric.length * .64);
        if (tangent != null) {
          canvas.drawCircle(
            tangent.position,
            3,
            Paint()
              ..color = AppColors.accent.withValues(
                alpha: reveal * (.3 + .15 * math.sin(phase * math.pi * 2)),
              ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_EnergyLandscape oldDelegate) =>
      reveal != oldDelegate.reveal || phase != oldDelegate.phase;
}
