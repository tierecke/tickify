import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_list.dart';

class LocalRepository {
  static const String _listsKey = 'user_lists';

  Future<void> saveList(UserList list) async {
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
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(lists.map((l) => l.toJson()).toList());
    await prefs.setString(_listsKey, jsonString);
  }

  Future<List<UserList>> loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_listsKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => UserList.fromJson(json)).toList();
  }

  Future<void> deleteList(String listId) async {
    final prefs = await SharedPreferences.getInstance();
    final lists = await loadLists();
    lists.removeWhere((l) => l.id == listId);
    await _saveAllLists(lists);
  }
}
