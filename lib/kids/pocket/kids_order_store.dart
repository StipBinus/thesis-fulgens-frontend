import 'package:shared_preferences/shared_preferences.dart';

// Saved order of the cards on the savings page
class KidsOrderStore {
  static const String _key = 'kids_savings_order_v1';

  static String pocketKey(int id) => 'p:$id';

  static String goalKey(int id) => 'g:$id';

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const <String>[];
  }

  Future<void> save(List<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, keys);
  }
}
