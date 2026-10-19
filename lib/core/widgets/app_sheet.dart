import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Branded bottom sheet wrapper with grab handle + title bar.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? trailing,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AppSheet(
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        child: builder(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width selectable row used inside sheets (item / option pickers).
class SheetOptionTile extends StatelessWidget {
  const SheetOptionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.selected = false,
    this.enabled = true,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryDeep,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
