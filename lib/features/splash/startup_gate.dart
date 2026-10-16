import 'package:flutter/material.dart';

import 'splash_screen.dart';

/// Draws the splash before initialization, and keeps it visible for its entrance.
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.initialize, required this.child});

  final Future<void> Function() initialize;
  final Widget child;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Native launch hands over to our first frame before plugins begin work.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    setState(() => _failed = false);
    try {
      await Future.wait([
        Future<void>.sync(widget.initialize),
        Future<void>.delayed(const Duration(milliseconds: 2200)),
      ]);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 450),
    child: _ready
        ? KeyedSubtree(key: const ValueKey('ready'), child: widget.child)
        : SplashScreen(
            key: const ValueKey('splash'),
            onRetry: _failed ? _start : null,
          ),
  );
}
