import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_list.dart';

class LocalRepository {
  static const String _listsKey = 'lists';

  Future<void> saveList(UserList list) async {
    print(
        'Saving list with unsynchronized changes: ${list.hasUnsynchronizedChanges}');
    final prefs = await SharedPreferences.getInstance();
    final lists = await loadLists();
    // Remove any existing list with the same id
    lists.removeWhere((l) => l.id == list.id);
    lists.add(list);
    await _saveAllLists(lists);
  }

  Future<void> saveAllLists(List<UserList> lists) async {
    await _saveAllLists(lists);
  }

  Future<void> _saveAllLists(List<UserList> lists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = lists.map((l) => l.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      print('Saving lists JSON: $jsonString');
      await prefs.setString(_listsKey, jsonString);
    } catch (e) {
      print('Error saving lists: $e');
      rethrow;
    }
  }

  Future<List<UserList>> loadLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_listsKey);
      if (jsonString == null) return [];

      print('Loading lists JSON: $jsonString');
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      final lists = jsonList.map((json) {
        if (json is Map<String, dynamic>) {
          final list = UserList.fromJson(json);
          print(
              'Loaded list ${list.id} with unsynchronized changes: ${list.hasUnsynchronizedChanges}');
          return list;
        }
        throw Exception('Invalid list item format: ${json.runtimeType}');
      }).toList();
      return lists;
    } catch (e) {
      print('Error loading lists: $e');
      return [];
    }
  }

  Future<UserList?> loadList(String listId) async {
    try {
      final lists = await loadLists();
      final list = lists.firstWhere((list) => list.id == listId);
      print(
          'Loaded list $listId with unsynchronized changes: ${list.hasUnsynchronizedChanges}');
      return list;
    } catch (e) {
      print('Error loading list $listId: $e');
      return null;
    }
  }

  Future<void> deleteList(String listId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lists = await loadLists();
      lists.removeWhere((l) => l.id == listId);
      await _saveAllLists(lists);
    } catch (e) {
      print('Error deleting list $listId: $e');
      rethrow;
    }
  }
}
