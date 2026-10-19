import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/toast.dart';
import '../../providers/app_info_providers.dart';
import '../../services/auth_service.dart';

/// Sign-in screen backed by Firebase Authentication (email + password).
/// On success the app-level auth gate swaps to the shell automatically.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _remember = true;
  String? _error;

  static const _prefsEmailKey = 'remembered_email';

  @override
  void initState() {
    super.initState();
    _loadRemembered();
  }

  Future<void> _loadRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsEmailKey);
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _email.text = saved;
        _remember = true;
      });
    }
  }

  Future<void> _persistRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    if (_remember) {
      await prefs.setString(_prefsEmailKey, _email.text.trim());
    } else {
      await prefs.remove(_prefsEmailKey);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.signIn(email: _email.text, password: _password.text);
      // Offer to save the credentials with the OS password manager.
      TextInput.finishAutofillContext();
      await _persistRemembered();
      // AuthGate reacts to the auth state change — no navigation needed here.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AuthService.messageFor(e);
      });
    }
  }

  Future<void> _forgotPassword() async {
    final input = _email.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Enter your username first.');
      return;
    }
    if (!input.contains('@')) {
      if (!mounted) return;
      AppToast.info(context, 'Ask your administrator to reset your password.');
      return;
    }
    try {
      await AuthService.sendPasswordReset(input);
      if (!mounted) return;
      AppToast.success(context, 'Password reset link sent to $input');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, AuthService.messageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 5, child: _BrandPanel()),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 48,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _formCard(context),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _MobileHero(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: _formCard(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _formCard(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
      shadow: AppTheme.softShadow,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sign in', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Access the Oxen Energies inventory workspace.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, child: child),
              ),
              child: _error == null
                  ? const SizedBox.shrink(key: ValueKey('no-error'))
                  : _ErrorBanner(
                      key: ValueKey(_error),
                      message: _error!,
                      onDismiss: () => setState(() => _error = null),
                    ),
            ),
            if (_error != null) const SizedBox(height: 16),
            AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _email,
                    label: 'Username',
                    hint: 'e.g. Oxenstore',
                    prefixIcon: Icons.person_rounded,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    required: true,
                    onChanged: (_) => _clearError(),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Username is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _password,
                    label: 'Password',
                    hint: '••••••••',
                    prefixIcon: Icons.lock_rounded,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    required: true,
                    onChanged: (_) => _clearError(),
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      tooltip: _obscure ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20,
                      ),
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Password is required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _remember = !_remember),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _remember,
                                  onChanged: (v) =>
                                      setState(() => _remember = v ?? false),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Remember me',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 158),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            textStyle: theme.textTheme.labelMedium,
                          ),
                          onPressed: _loading ? null : _forgotPassword,
                          child: const Text(
                            'Forgot password?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'Sign in',
                    loading: _loading,
                    onTap: _submit,
                    icon: Icons.login_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Consumer(
                builder: (context, ref, _) => Text(
                  'Oxen Energies • v${ref.watch(appVersionProvider).value ?? ''}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 19,
            color: AppColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                height: 1.4,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.close_rounded,
              size: 17,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileHero extends StatelessWidget {
  const _MobileHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 44, 24, 34),
      decoration: const BoxDecoration(
        gradient: AppColors.navyGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(onDark: true),
            const SizedBox(height: 34),
            Text(
              'Stock control,\nmade effortless.',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Panels • Inverters • Batteries • Site material',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _highlights = [
    ('Real-time stock levels', 'Know exactly what is on the yard, every hour.'),
    ('Challans & movements', 'Track every inbound and outbound consignment.'),
    ('Reports that export', 'PDF challans and summaries in a couple of taps.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.navyGradient),
      padding: const EdgeInsets.all(56),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(onDark: true),
            const Spacer(),
            Text(
              'Run your solar\ninventory with\nconfidence.',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                height: 1.22,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'One workspace for panels, inverters, batteries and site material — from purchase challan to dispatch.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            for (final (title, subtitle) in _highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: AppColors.accentBright,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Text(
              'Oxen Energies • Inventory Suite',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
