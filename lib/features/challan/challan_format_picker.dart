import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/challan.dart';

/// Radio-style selector for the challan PDF layout template.
class ChallanFormatPicker extends StatelessWidget {
  const ChallanFormatPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final ChallanFormat value;
  final ValueChanged<ChallanFormat> onChanged;

  /// Tighter spacing, used when the picker sits inside an existing card.
  final bool dense;

  static IconData _icon(ChallanFormat format) => switch (format) {
    ChallanFormat.letterhead => Icons.receipt_long_rounded,
    ChallanFormat.plain => Icons.description_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < ChallanFormat.values.length; i++) ...[
          if (i > 0) SizedBox(height: dense ? 8 : 10),
          _FormatTile(
            format: ChallanFormat.values[i],
            selected: ChallanFormat.values[i] == value,
            dense: dense,
            onTap: () => onChanged(ChallanFormat.values[i]),
          ),
        ],
      ],
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.selected,
    required this.onTap,
    required this.dense,
  });

  final ChallanFormat format;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = ChallanFormatPicker._icon(format);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.all(dense ? 11 : 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 19,
                color: selected
                    ? AppColors.primaryDeep
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 13.5,
                      color: selected
                          ? AppColors.primaryDeep
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    format.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.primaryDeep : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
