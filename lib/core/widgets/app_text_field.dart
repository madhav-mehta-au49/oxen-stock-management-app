import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// Labelled text field with consistent spacing and optional prefix/suffix.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.maxLength,
    this.inputFormatters,
    this.autofocus = false,
    this.required = false,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool autofocus;
  final bool required;
  final bool obscureText;
  final TextCapitalization textCapitalization;

  /// Autofill hints (e.g. [AutofillHints.email]) — lets the OS password
  /// manager save and autofill credentials.
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            children: [
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.danger),
                ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          autofocus: autofocus,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          autofillHints: autofillHints,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontSize: 14.5,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20),
            suffixIcon: suffix,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

/// Read-only field that opens a bottom sheet / date picker on tap.
class AppPickerField extends StatelessWidget {
  const AppPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.prefixIcon,
    this.validator,
    this.required = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? hint;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;
  final bool required;

  bool get _isEmpty => value.trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
            children: [
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.danger),
                ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        FormField<String>(
          validator: validator,
          initialValue: value,
          builder: (field) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
                  suffixIcon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: AppColors.textMuted,
                  ),
                  errorText: field.errorText,
                  fillColor: AppColors.surface,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEmpty ? (hint ?? '') : value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _isEmpty
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
