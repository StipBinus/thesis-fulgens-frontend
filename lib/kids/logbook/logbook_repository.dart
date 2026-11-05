import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'logbook_models.dart';

// Local persistence so an ApiLogbookRepository can replace this later.
abstract class LogbookRepository {
  Future<LogbookState?> load();

  Future<void> save(LogbookState state);
}

class PrefsLogbookRepository implements LogbookRepository {
  // Bumped from 'logbook_v1': entries previously stored a fixed pocket name
  // ('cash', 'snack', …) and a local wallet, which no longer matches the
  // `pocketId` schema.
  // static const String _storageKey = 'logbook_v1';
  static const String _storageKey = 'logbook_v2';

  @override
  Future<LogbookState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      return LogbookState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(LogbookState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }
}

final logbookRepositoryProvider = Provider<LogbookRepository>(
  (ref) => PrefsLogbookRepository(),
);
