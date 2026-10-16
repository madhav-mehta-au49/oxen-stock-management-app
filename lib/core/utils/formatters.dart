import 'package:intl/intl.dart';

/// Display formatters shared across screens.
class Fmt {
  const Fmt._();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final NumberFormat _inrCompact = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static final NumberFormat _number = NumberFormat.decimalPattern('en_IN');

  static final DateFormat day = DateFormat('dd MMM yyyy');
  static final DateFormat dayShort = DateFormat('dd MMM');
  static final DateFormat time = DateFormat('hh:mm a');
  static final DateFormat _dayTime = DateFormat('dd MMM • hh:mm a');
  static final DateFormat monthYear = DateFormat('MMM yyyy');

  static String currency(num value) => _inr.format(value);

  static String currencyCompact(num value) =>
      value >= 100000 ? _inrCompact.format(value) : _inr.format(value);

  static String number(num value) => _number.format(value);

  static String date(DateTime d) => day.format(d);

  static String shortDate(DateTime d) => dayShort.format(d);

  static String timeOf(DateTime d) => time.format(d);

  static String dayTime(DateTime d) => _dayTime.format(d);

  static String relativeDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return day.format(d);
  }

  static String qty(int value, String unit) => '$value $unit';
}
