import 'daily_task.dart';

// Flip these while reviewing the screen. Both die once the GET endpoint lands.
const bool _mockNoTask = false;
const bool _mockUseReflection = false;

/// The single seam between the Tasks screen and the backend.
///
/// Live wiring is two method bodies: swap [todayTask] for
/// `FinanceApi().get('/api/daily-task/children/$id/today')` and [submit] for
/// `FinanceApi().post('/api/daily-task/daily-task/$taskId/submit-answer', body)`.
class DailyTaskRepository {
  Future<DailyTask?> todayTask() async {
    if (_mockNoTask) return null;
    final today = DateTime.now();
    return DailyTask(
      taskId: 1,
      childId: 'mock-child',
      taskDate: DateTime(today.year, today.month, today.day),
      questionType: _mockUseReflection ? 'REFLECTION' : 'MULTIPLE_CHOICE',
      question: _mockUseReflection
          ? 'You spent Rp25.000 on snacks this week. Was that planned, or did it just happen?'
          : 'You saved Rp15.000 this week. What is the smartest thing to do with it?',
      options: _mockUseReflection
          ? const <String>[]
          : const <String>[
              'Spend it all today',
              'Keep saving for your goal',
              'Lend it to a friend',
              'Buy a snack for now',
            ],
      reward: 20,
      status: 'PENDING',
    );
  }

  Future<DailyTaskAnswer> submit({
    required int taskId,
    String? answerText,
    String? selectedAnswer,
  }) async {
    return DailyTaskAnswer(
      answerId: 1,
      taskId: taskId,
      answerText: answerText,
      selectedAnswer: selectedAnswer,
      submittedAt: DateTime.now(),
    );
  }
}
