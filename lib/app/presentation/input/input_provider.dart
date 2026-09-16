import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple state for the Input sheet.
/// Expand this class with fields you need (e.g. name, age, imagePath).
/// Keeping it as a separate class makes it easy to swap mock -> real API later.
class InputState {
  const InputState({this.text = ''});

  final String text;

  InputState copyWith({String? text}) {
    return InputState(text: text ?? this.text);
  }
}

/// Riverpod Notifier for InputPage.
/// This is the "central whiteboard" that both Home and Input sheet can read/write.
class InputNotifier extends Notifier<InputState> {
  @override
  InputState build() => const InputState();

  void updateText(String value) {
    state = state.copyWith(text: value);
  }

  void clear() {
    state = const InputState();
  }
}

final inputProvider = NotifierProvider<InputNotifier, InputState>(
  InputNotifier.new,
);
