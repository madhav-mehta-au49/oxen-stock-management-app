import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/category_repository.dart';
import '../data/repositories/meta_repository.dart';
import '../data/repositories/user_repository.dart';
import '../models/app_user.dart';
import '../models/company_profile.dart';
import '../services/auth_service.dart';

/// Emits the signed-in user (or `null` when signed out) and drives the auth gate.
final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService.authStateChanges();
});

/// Firestore profile (`users/{uid}`) for the signed-in user.
final userProfileProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return const UserRepository().watchProfile(uid);
});

/// All user profiles (admin management).
final allUsersProvider = StreamProvider<List<AppUser>>(
  (ref) => const UserRepository().watchUsers(),
);

/// True when the signed-in user has [permission] (admins always do).
bool can(WidgetRef ref, String permission) =>
    ref.watch(userProfileProvider).valueOrNull?.can(permission) ?? false;

/// Runs once per signed-in session: ensures the user profile doc and seeds the
/// company profile if the database is empty.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return;
  await const UserRepository().ensureProfile(
    uid: user.uid,
    email: user.email ?? '',
  );
  await const MetaRepository().seedIfEmpty(CompanyProfile.fallback);
  await const CategoryRepository().seedIfEmpty();
  // Admins carry the legacy `meta/tax` GST rates onto the categories once.
  final profile = await const UserRepository().getProfile(user.uid);
  if (profile?.isAdmin ?? false) {
    await const CategoryRepository().migrateGstFromLegacyTax();
  }
});
