// Mirrors the backend DailyTaskResponse payload, field for field.
class DailyTask {
  const DailyTask({
    required this.taskId,
    required this.childId,
    required this.taskDate,
    required this.questionType,
    required this.question,
    required this.options,
    required this.reward,
    required this.status,
  });

  final int taskId;
  final String childId;
  final DateTime taskDate;
  final String questionType;
  final String question;
  final List<String> options;
  final int reward;
  final String status;

  bool get isMultipleChoice => questionType == 'MULTIPLE_CHOICE';
  bool get isReflection => questionType == 'REFLECTION';
  bool get isDone => status == 'COMPLETED';

  DailyTask copyWith({String? status}) => DailyTask(
    taskId: taskId,
    childId: childId,
    taskDate: taskDate,
    questionType: questionType,
    question: question,
    options: options,
    reward: reward,
    status: status ?? this.status,
  );

  factory DailyTask.fromJson(Map<String, dynamic> json) => DailyTask(
    taskId: (json['taskId'] as num?)?.toInt() ?? 0,
    childId: json['childId'] as String? ?? '',
    taskDate:
        DateTime.tryParse(json['taskDate'] as String? ?? '') ?? DateTime.now(),
    questionType: json['questionType'] as String? ?? 'REFLECTION',
    question: json['question'] as String? ?? '',
    options:
        (json['options'] as List?)?.map((e) => e.toString()).toList() ??
        const <String>[],
    reward: (json['reward'] as num?)?.round() ?? 0,
    status: json['status'] as String? ?? 'PENDING',
  );
}

// Mirrors the backend DailyTaskAnswerResponse payload.
class DailyTaskAnswer {
  const DailyTaskAnswer({
    required this.answerId,
    required this.taskId,
    this.answerText,
    this.selectedAnswer,
    required this.submittedAt,
  });

  final int answerId;
  final int taskId;
  final String? answerText;
  final String? selectedAnswer;
  final DateTime submittedAt;

  factory DailyTaskAnswer.fromJson(Map<String, dynamic> json) =>
      DailyTaskAnswer(
        answerId: (json['answerId'] as num?)?.toInt() ?? 0,
        taskId: (json['taskId'] as num?)?.toInt() ?? 0,
        answerText: json['answerText'] as String?,
        selectedAnswer: json['selectedAnswer'] as String?,
        submittedAt:
            DateTime.tryParse(json['submittedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
