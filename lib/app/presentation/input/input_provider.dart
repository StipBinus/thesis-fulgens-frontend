import 'package:flutter_riverpod/flutter_riverpod.dart';

// Input state
class InputState {
  const InputState({
    this.text = '',
  });

  final String text;

  InputState copyWith({String? text}) {
    return InputState(text: text ?? this.text);
  }
}

// Input notifier
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
