// Data models for the parent home page.
//
// The spending chart comes from
// `GET /api/transaction-logs/child/{childId}/profile-finance-chart`.

/// The latest prompt a parent saved for a child, from
/// `GET /api/parent-task/prompt`. Stored on the server as
/// "{prompt} question example: {q1} | {q2}"; the backend splits it.
class LatestParentPrompt {
  const LatestParentPrompt({
    required this.prompt,
    required this.questionExamples,
    this.createdAt,
  });

  final String prompt;
  final List<String> questionExamples;
  final DateTime? createdAt;

  factory LatestParentPrompt.fromJson(Map<String, dynamic> json) {
    final examples = json['questionExamples'];
    return LatestParentPrompt(
      prompt: (json['prompt'] as String? ?? json['rawPrompt'] as String? ?? '')
          .trim(),
      questionExamples: examples is List
          ? examples
                .map((e) => '$e'.trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[],
      createdAt: _dateValue(json['createdAt']),
    );
  }
}

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

/// One daily task of a child as the parent sees it, from
/// `GET /api/daily-task/parent/children/{childId}`.
///
/// Status: PENDING (not answered) -> WAITING (answered, needs the parent's
/// approval) -> COMPLETED (approved). The answer fields are null while
/// PENDING.
class ChildTaskAnswer {
  const ChildTaskAnswer({
    required this.taskId,
    required this.taskDate,
    required this.questionType,
    required this.question,
    required this.options,
    required this.reward,
    required this.status,
    this.answerText,
    this.selectedAnswer,
    this.submittedAt,
    this.updatedAt,
  });

  static const String pending = 'PENDING';
  static const String waiting = 'WAITING';
  static const String completed = 'COMPLETED';

  final int taskId;
  final DateTime taskDate;
  final String questionType;
  final String question;
  final List<String> options;
  final int reward;
  final String status;
  final String? answerText;
  final String? selectedAnswer;
  final DateTime? submittedAt;
  final DateTime? updatedAt;

  /// The child's reply, whichever field holds it.
  String? get answer => answerText ?? selectedAnswer;

  factory ChildTaskAnswer.fromJson(Map<String, dynamic> json) {
    return ChildTaskAnswer(
      taskId: (json['taskId'] as num?)?.toInt() ?? 0,
      taskDate:
          DateTime.tryParse(json['taskDate'] as String? ?? '') ??
          DateTime.now(),
      questionType: json['questionType'] as String? ?? 'REFLECTION',
      question: json['question'] as String? ?? '',
      options:
          (json['options'] as List?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      reward: (json['reward'] as num?)?.round() ?? 0,
      status: json['status'] as String? ?? pending,
      answerText: json['answerText'] as String?,
      selectedAnswer: json['selectedAnswer'] as String?,
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }
}
