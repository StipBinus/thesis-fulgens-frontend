import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The child currently shown on the parent home page.
///
/// Lifted out of the children card so the calendar and the spending chart below
/// it can follow the selected tab without either widget having to hold a
/// reference to the others.
class SelectedChildId extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String childId) {
    if (state == childId) return;
    state = childId;
  }
}

final selectedChildIdProvider =
    NotifierProvider<SelectedChildId, String?>(SelectedChildId.new);
