import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Saved order of the cards on the savings page
class KidsOrderStore {
  static const String _key = 'kids_savings_order_v1';

  // Latest order, shared with every page that mirrors it
  static final ValueNotifier<List<String>> changes =
      ValueNotifier<List<String>>(const <String>[]);

  static String pocketKey(String id) => 'p:$id';

  static String goalKey(String id) => 'g:$id';

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const <String>[];
  }

  Future<void> save(List<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, keys);
    changes.value = List<String>.unmodifiable(keys);
  }
}
