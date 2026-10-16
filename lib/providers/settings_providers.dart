import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/meta_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../models/app_settings.dart';
import '../models/challan.dart';
import '../models/company_profile.dart';
import 'auth_providers.dart';

// ---------------------------------------------------------------- settings

final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(AppSettings.defaults);
  return const SettingsRepository().watch(uid);
});

class SettingsController {
  SettingsController(this._ref);
  final Ref _ref;

  Future<void> update(AppSettings settings) async {
    final uid = _ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    await const SettingsRepository().save(uid, settings);
  }

  Future<void> toggleLowStock(bool value) async {
    final current = _ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    await update(current.copyWith(lowStockAlerts: value));
  }

  Future<void> toggleDailySummary(bool value) async {
    final current = _ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    await update(current.copyWith(dailySummary: value));
  }

  Future<void> toggleAutoRefresh(bool value) async {
    final current = _ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    await update(current.copyWith(autoRefresh: value));
  }

  Future<void> setDefaultFormat(ChallanFormat format) async {
    final current = _ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    await update(current.copyWith(defaultChallanFormat: format));
  }
}

final settingsControllerProvider =
    Provider<SettingsController>((ref) => SettingsController(ref));

// ----------------------------------------------------------- company profile

final companyProfileProvider = StreamProvider<CompanyProfile>((ref) {
  return const MetaRepository().watchCompany();
});

/// Saves the company profile (`meta/company`) — admin action.
final companySaveProvider =
    Provider<Future<void> Function(CompanyProfile)>((ref) {
  return const MetaRepository().saveCompany;
});
