import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/stock_item.dart';

/// Local (on-device) notifications. No server needed.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const String _channelId = 'oxen_low_stock';
  static const String _channelName = 'Low stock alerts';
  static const String _channelDesc =
      'Alerts when an item reaches its reorder level';

  static Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );
    _ready = true;
  }

  /// Asks for POST_NOTIFICATIONS on Android 13+.
  static Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  static Future<void> showLowStock(StockItem item) async {
    if (!_ready) return;
    final body = item.isOutOfStock
        ? '${item.name} is OUT of stock.'
        : '${item.name} is low — ${item.quantity} ${item.unit} left '
              '(reorder level ${item.reorderLevel}).';

    await _show('Low stock alert', body);
  }

  static Future<void> showSummary(String title, String body) async {
    if (!_ready) return;
    await _show(title, body);
  }

  static Future<void> _show(String title, String body, {int id = 0}) async {
    await _plugin.show(
      id: id == 0 ? DateTime.now().millisecondsSinceEpoch & 0x7fffffff : id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
    );
  }
}
