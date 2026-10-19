import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, navy, outline, ghost, danger, success }

/// Primary call-to-action button with the 4 supported visual variants.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.height = 52,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final double height;
  final bool dense;

  bool get _enabled => onTap != null && !loading;

  @override
  Widget build(BuildContext context) {
    final scheme = switch (variant) {
      AppButtonVariant.primary => _Colors(
        bg: AppColors.primary,
        fg: Colors.white,
      ),
      AppButtonVariant.navy => _Colors(bg: AppColors.navy, fg: Colors.white),
      AppButtonVariant.success => _Colors(
        bg: AppColors.success,
        fg: Colors.white,
      ),
      AppButtonVariant.danger => _Colors(
        bg: AppColors.danger,
        fg: Colors.white,
      ),
      AppButtonVariant.outline => _Colors(
        bg: Colors.transparent,
        fg: AppColors.textPrimary,
      ),
      AppButtonVariant.ghost => _Colors(
        bg: Colors.transparent,
        fg: AppColors.primaryDeep,
      ),
    };

    final Widget content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(scheme.fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 17 : 19, color: scheme.fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: scheme.fg,
                    fontWeight: FontWeight.w600,
                    fontSize: dense ? 13 : 14.5,
                  ),
                ),
              ),
            ],
          );

    final style = TextButton.styleFrom(
      backgroundColor: scheme.bg,
      foregroundColor: scheme.fg,
      disabledBackgroundColor:
          variant == AppButtonVariant.outline ||
              variant == AppButtonVariant.ghost
          ? Colors.transparent
          : const Color(0xFFE2E5EC),
      disabledForegroundColor: const Color(0xFFA6ADBA),
      minimumSize: Size(expanded ? double.infinity : 0, height),
      padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 22),
      side: variant == AppButtonVariant.outline
          ? const BorderSide(color: AppColors.border)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          variant == AppButtonVariant.ghost ? 8 : AppTheme.radius,
        ),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge,
    );

    final button = TextButton(
      onPressed: _enabled ? onTap : null,
      style: style,
      child: content,
    );

    if (expanded) return button;
    return IntrinsicWidth(child: button);
  }
}

class _Colors {
  const _Colors({required this.bg, required this.fg});
  final Color bg;
  final Color fg;
}

/// Compact square icon button used for +/- quick actions.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppColors.navy,
    this.bg = AppColors.primarySoft,
    this.size = 40,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color bg;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final w = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: size * 0.55, color: color),
    );

    final button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: w,
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
