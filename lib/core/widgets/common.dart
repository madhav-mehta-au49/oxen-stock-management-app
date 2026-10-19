import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../models/item_glyph.dart';
import '../../models/stock_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Oxen Energies brand lockup using the exact supplied logo asset.
///
/// [onDark] places the logo on a white chip so the original colours stay
/// legible over navy headers / the login hero. The vertical wordmark keeps its
/// native aspect ratio.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.scale = 1,
    this.onDark = false,
    this.compact = false,
  });

  final double scale;
  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/brand/oxen_logo.png',
      height: 22 * scale,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    final mark = onDark
        ? Container(
            padding: EdgeInsets.symmetric(
              horizontal: 10 * scale,
              vertical: 7 * scale,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10 * scale),
            ),
            child: logo,
          )
        : logo;

    final subColor = onDark ? Colors.white60 : AppColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        if (!compact) ...[
          SizedBox(height: 5 * scale),
          Text(
            'STOCK MANAGER',
            style: TextStyle(
              fontSize: 8.5 * scale,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4 * scale,
              color: subColor,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}

/// Coloured rounded avatar that stands in for a product photo.
class ItemAvatar extends StatelessWidget {
  const ItemAvatar({
    super.key,
    required this.item,
    this.size = 48,
    this.radius = 12,
  });

  final StockItem item;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final thumb = _thumb();
    if (thumb != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          thumb,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      );
    }

    final glyph = ItemGlyph.byKey(item.glyphKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: glyph.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(glyph.icon, color: glyph.color, size: size * 0.48),
    );
  }

  Uint8List? _thumb() {
    if (item.imageThumb.isEmpty) return null;
    try {
      return base64Decode(item.imageThumb);
    } catch (_) {
      return null;
    }
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  actionLabel!,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.bg,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final Color? bg;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.primaryDeep),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              ActionChip(
                onPressed: onAction,
                label: Text(actionLabel!),
                backgroundColor: AppColors.navy,
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
