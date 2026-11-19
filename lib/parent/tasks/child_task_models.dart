/// Models for the "Add child > set daily questions" flow.
///
/// The child account is only created after the parent approves the previewed
/// questions, so [ChildDraft] carries everything the register endpoint needs
/// while the parent reviews the questions.
class ChildDraft {
  const ChildDraft({
    required this.name,
    required this.username,
    required this.password,
    required this.birthDate,
    required this.grade,
    required this.parentId,
    required this.prompt,
  });

  final String name;
  final String username;
  final String password;
  final DateTime birthDate;
  final String grade;
  final String parentId;

  /// Parent's instruction, at most [maxPromptLength] characters.
  ///
  /// Kept short so the composed prompt (this text plus the example questions)
  /// still fits the backend's 512 character limit.
  final String prompt;

  static const int maxPromptLength = 200;

  Map<String, dynamic> toRegisterJson(String composedPrompt) {
    return {
      'name': name,
      'username': username,
      'password': password,
      'birthDate': birthDate.toIso8601String().split('T').first,
      'grade': grade,
      'parentId': parentId,
      'prompt': composedPrompt,
    };
  }
}

/// One question returned by `GET /api/parent-task/preview`.
class PreviewQuestion {
  const PreviewQuestion({
    required this.questionType,
    required this.question,
    this.options = const [],
    this.correctAnswer,
    required this.reward,
  });

  /// `REFLECTION` or `MULTIPLE_CHOICE`.
  final String questionType;
  final String question;
  final List<String> options;
  final String? correctAnswer;
  final int reward;

  String get typeLabel {
    switch (questionType.trim().toUpperCase()) {
      case 'MULTIPLE_CHOICE':
        return 'Multiple choice';
      case 'REFLECTION':
        return 'Reflection';
      default:
        return 'Question';
    }
  }

  factory PreviewQuestion.fromJson(Map<String, dynamic> json) {
    return PreviewQuestion(
      questionType: json['questionType'] as String? ?? 'REFLECTION',
      question: json['question'] as String? ?? '',
      options:
          (json['options'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .map((option) => option.trim())
              .where((option) => option.isNotEmpty)
              .toList(),
      correctAnswer: json['correctAnswer'] as String?,
      reward: _intValue(json['reward']),
    );
  }
}

/// Whole payload of the task preview endpoint.
class TaskPreview {
  const TaskPreview({required this.prompt, required this.dailyTasks});

  /// The prompt the backend used, echoed back.
  final String prompt;

  /// Weekly preview is not developed yet, so the response always sends null.
  final List<PreviewQuestion> dailyTasks;

  factory TaskPreview.fromJson(Map<String, dynamic> json) {
    return TaskPreview(
      prompt: json['prompt'] as String? ?? '',
      dailyTasks:
          (json['dailyTasks'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(PreviewQuestion.fromJson)
              .toList(),
    );
  }
}

/// Longest prompt the backend accepts (`parent_prompt.prompt` is 512).
const int maxComposedPromptLength = 512;

/// Builds the prompt that is saved with the new child:
///
/// `"<parent prompt> questions example: Q1 | Q2 | Q3"`
///
/// The result is trimmed to [maxComposedPromptLength] characters so the
/// register request never fails on the backend's length check.
String composeChildPrompt(String prompt, List<String> questions) {
  final base = prompt.trim();
  final cleaned =
      questions
          .map((question) => question.trim())
          .where((question) => question.isNotEmpty)
          .toList();

  if (cleaned.isEmpty) {
    return _truncate(base, maxComposedPromptLength);
  }

  return _truncate(
    '$base questions example: ${cleaned.join(' | ')}',
    maxComposedPromptLength,
  );
}

/// Cuts [value] to [limit] characters without leaving half a word behind.
String _truncate(String value, int limit) {
  if (value.length <= limit) return value;

  final cut = value.substring(0, limit);
  final lastSpace = cut.lastIndexOf(' ');
  final trimmed = lastSpace > limit * 0.6 ? cut.substring(0, lastSpace) : cut;

  return trimmed.trimRight();
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
