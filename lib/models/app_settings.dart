import 'challan.dart';

/// Per-user preferences stored at `settings/{uid}`.
class AppSettings {
  const AppSettings({
    required this.lowStockAlerts,
    required this.dailySummary,
    required this.autoRefresh,
    required this.defaultChallanFormat,
    this.summaryTime = '08:00',
  });

  final bool lowStockAlerts;
  final bool dailySummary;
  final bool autoRefresh;
  final ChallanFormat defaultChallanFormat;

  /// Daily summary time as `HH:mm` (24h).
  final String summaryTime;

  static const AppSettings defaults = AppSettings(
    lowStockAlerts: true,
    dailySummary: false,
    autoRefresh: true,
    defaultChallanFormat: ChallanFormat.letterhead,
  );

  /// Parsed `(hour, minute)` for [summaryTime].
  (int, int) get summaryTimeParts {
    final parts = summaryTime.split(':');
    final h = int.tryParse(parts.first) ?? 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return (h.clamp(0, 23), m.clamp(0, 59));
  }

  Map<String, dynamic> toMap() => {
    'lowStockAlerts': lowStockAlerts,
    'dailySummary': dailySummary,
    'autoRefresh': autoRefresh,
    'defaultChallanFormat': defaultChallanFormat.name,
    'summaryTime': summaryTime,
  };

  factory AppSettings.fromMap(Map<String, dynamic> data) => AppSettings(
    lowStockAlerts: data['lowStockAlerts'] as bool? ?? true,
    dailySummary: data['dailySummary'] as bool? ?? false,
    autoRefresh: data['autoRefresh'] as bool? ?? true,
    defaultChallanFormat: ChallanFormat.values.firstWhere(
      (f) => f.name == data['defaultChallanFormat'],
      orElse: () => ChallanFormat.letterhead,
    ),
    summaryTime: data['summaryTime'] as String? ?? '08:00',
  );

  AppSettings copyWith({
    bool? lowStockAlerts,
    bool? dailySummary,
    bool? autoRefresh,
    ChallanFormat? defaultChallanFormat,
    String? summaryTime,
  }) => AppSettings(
    lowStockAlerts: lowStockAlerts ?? this.lowStockAlerts,
    dailySummary: dailySummary ?? this.dailySummary,
    autoRefresh: autoRefresh ?? this.autoRefresh,
    defaultChallanFormat: defaultChallanFormat ?? this.defaultChallanFormat,
    summaryTime: summaryTime ?? this.summaryTime,
  );
}
