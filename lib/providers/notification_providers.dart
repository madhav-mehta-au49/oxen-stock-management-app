import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/notification_repository.dart';
import '../models/app_notification.dart';
import 'auth_providers.dart';

final notificationsProvider = StreamProvider<List<AppNotification>>(
  (ref) => const NotificationRepository().watchRecent(),
);

final notificationsSeenAtProvider = StreamProvider<DateTime?>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value(null);
  return const NotificationRepository().watchSeenAt(uid);
});

/// Number of notifications newer than the user's last-seen timestamp.
final unreadNotificationsProvider = Provider<int>((ref) {
  final list =
      ref.watch(notificationsProvider).value ?? const <AppNotification>[];
  final seen = ref.watch(notificationsSeenAtProvider).value;
  if (seen == null) return list.length;
  return list.where((n) => n.createdAt.isAfter(seen)).length;
});
