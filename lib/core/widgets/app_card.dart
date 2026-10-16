import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// White rounded card used across the app (12px radius + soft shadow).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.color = AppColors.surface,
    this.border,
    this.onTap,
    this.shadow = AppTheme.cardShadow,
    this.radius = AppTheme.radius,
    this.width = double.infinity,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final Border? border;
  final VoidCallback? onTap;
  final List<BoxShadow> shadow;
  final double radius;

  /// Set to a finite value to shrink-wrap the card (e.g. inside a Row).
  final double width;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}

/// Horizontal page padding helper.
class PagePadding extends StatelessWidget {
  const PagePadding({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(padding: padding, child: child);
}
