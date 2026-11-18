// Data models for the parent home page.
//
// The spending chart comes from
// `GET /api/transaction-logs/child/{childId}/profile-finance-chart`.

/// Time window offered by the "This month" dropdown on the spending card.
enum SpendingPeriod {
  thisMonth('This month'),
  lastMonth('Last month'),
  lastThreeMonths('Last 3 months');

  const SpendingPeriod(this.label);

  final String label;

  /// Inclusive date range sent to the backend as `startDate` / `endDate`.
  ({DateTime start, DateTime end}) range(DateTime now) {
    switch (this) {
      case SpendingPeriod.thisMonth:
        return (
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );

      case SpendingPeriod.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        return (start: start, end: end);

      case SpendingPeriod.lastThreeMonths:
        return (
          start: DateTime(now.year, now.month - 2, 1),
          end: DateTime(now.year, now.month, now.day),
        );
    }
  }
}

/// One category slice of the spending donut.
class SpendingSlice {
  const SpendingSlice({
    required this.label,
    required this.amount,
    required this.percentage,
  });

  /// Raw backend enum, e.g. `FOOD_AND_BEVERAGE`.
  final String label;

  final int amount;

  /// 0 - 100, as calculated by the backend.
  final double percentage;

  String get displayLabel => spendingCategoryLabel(label);

  factory SpendingSlice.fromJson(Map<String, dynamic> json) {
    return SpendingSlice(
      label: json['label'] as String? ?? '',
      amount: _intValue(json['amount']),
      percentage: _doubleValue(json['percentage']),
    );
  }
}

/// Whole payload of the profile finance chart endpoint.
class SpendingChartData {
  const SpendingChartData({
    required this.childId,
    required this.startDate,
    required this.endDate,
    required this.slices,
  });

  final String childId;
  final DateTime startDate;
  final DateTime endDate;

  /// Biggest slice first, so the donut and the legend read the same way.
  final List<SpendingSlice> slices;

  int get total => slices.fold(0, (sum, slice) => sum + slice.amount);

  bool get isEmpty => total <= 0;

  factory SpendingChartData.fromJson(
    Map<String, dynamic> json, {
    required String childId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final rawSlices = json['data'] as List<dynamic>? ?? const [];
    final slices =
        rawSlices
            .whereType<Map<String, dynamic>>()
            .map(SpendingSlice.fromJson)
            // fl_chart cannot draw a zero-value section.
            .where((slice) => slice.amount > 0)
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return SpendingChartData(
      childId: json['childId'] as String? ?? childId,
      startDate: _dateValue(json['startDate']) ?? startDate,
      endDate: _dateValue(json['endDate']) ?? endDate,
      slices: slices,
    );
  }
}

// Human labels for the backend `TransactionCategory` values. Savings is not a
// logbook category, but the chart endpoint reports it as one.
const Map<String, String> _spendingLabels = {
  'FOOD_AND_BEVERAGE': 'Food & Drinks',
  'TRANSPORT': 'Transportation',
  'ENTERTAINMENT': 'Games & Entertainment',
  'SCHOOL': 'Education',
  'HOBBY': 'Hobby',
  'OTHER': 'Others',
  'SAVINGS': 'Savings',
  'ALLOWANCE': 'Allowance',
  'GIFT': 'Gift',
};

/// `FOOD_AND_BEVERAGE` -> `Food & Drinks`; unknown values fall back to a
/// readable title-case form.
String spendingCategoryLabel(String raw) {
  final key = raw.trim().toUpperCase();
  final known = _spendingLabels[key];
  if (known != null) return known;
  if (key.isEmpty) return 'Others';

  return key
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0]}${word.substring(1).toLowerCase()}')
      .join(' ');
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

DateTime? _dateValue(dynamic value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
