/// Device-local prefs: cloud item IDs hidden on this device after "leave in cloud".
import 'package:shared_preferences/shared_preferences.dart';

class CloudSyncExclusionStore {
  static String _key(String userId) => 'cloud_sync_excluded_$userId';

  Future<Set<String>> loadExcludedIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key(userId)) ?? [];
    return list.toSet();
  }

  Future<void> addExcluded(String userId, String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await loadExcludedIds(userId);
    set.add(itemId);
    await prefs.setStringList(_key(userId), set.toList());
  }

  Future<void> removeExcluded(String userId, String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await loadExcludedIds(userId);
    set.remove(itemId);
    await prefs.setStringList(_key(userId), set.toList());
  }
}
