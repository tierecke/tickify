import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_list.dart';
import '../models/list_item.dart';

class LocalRepository {
  static const String _listsKey = 'lists';

  Future<void> saveList(UserList list) async {
    try {
      print('Saving list ${list.id} to SharedPreferences');
      print(
          'List has unsynchronized changes: ${list.hasUnsynchronizedChanges}');

      final prefs = await SharedPreferences.getInstance();
      final lists = await loadLists();

      // Find and update the list
      final index = lists.indexWhere((l) => l.id == list.id);
      if (index != -1) {
        // Create a new instance to ensure all changes are captured
        final updatedList = UserList(
          name: list.name,
          icon: list.icon,
          id: list.id,
          items: List<ListItem>.from(list.items),
          ownerId: list.ownerId,
          shared: List<SharedUser>.from(list.shared),
          isArchived: list.isArchived,
          createdAt: list.createdAt,
          lastOpenedAt: list.lastOpenedAt,
          lastModifiedAt: list.lastModifiedAt,
          hasUnsynchronizedChanges: list.hasUnsynchronizedChanges,
        );
        lists[index] = updatedList;
      } else {
        lists.add(list);
      }

      // Save all lists
      final jsonList = lists.map((l) => l.toJson()).toList();
      print('Saving ${jsonList.length} lists to SharedPreferences');
      print('JSON data: $jsonList');

      await prefs.setString('lists', jsonEncode(jsonList));

      // Verify the save
      final savedJson = prefs.getString('lists');
      if (savedJson == null) {
        throw Exception('Failed to save lists to SharedPreferences');
      }

      final savedLists = (jsonDecode(savedJson) as List)
          .map((json) => UserList.fromJson(json as Map<String, dynamic>))
          .toList();

      final savedList = savedLists.firstWhere((l) => l.id == list.id);
      print(
          'Verified save - List ${savedList.id} has unsynchronized changes: ${savedList.hasUnsynchronizedChanges}');

      if (savedList.hasUnsynchronizedChanges != list.hasUnsynchronizedChanges) {
        throw Exception('Sync state mismatch after save');
      }
    } catch (e) {
      print('Error saving list to SharedPreferences: $e');
      rethrow;
    }
  }

  Future<void> saveAllLists(List<UserList> lists) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = lists.map((l) => l.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      print('Saving all lists to SharedPreferences: $jsonString');

      // Save to SharedPreferences
      final success = await prefs.setString(_listsKey, jsonString);
      if (!success) {
        throw Exception('Failed to save to SharedPreferences');
      }

      // Verify the save
      final savedJson = prefs.getString(_listsKey);
      if (savedJson == null) {
        throw Exception('Failed to verify save - no data found');
      }
      print('Verified saved data: $savedJson');

      // Verify all lists were saved correctly
      final savedLists = await loadLists();
      for (var list in lists) {
        final savedList = savedLists.firstWhere((l) => l.id == list.id);
        print(
            'Verified list state - ID: ${savedList.id}, Has unsynchronized changes: ${savedList.hasUnsynchronizedChanges}');

        if (savedList.hasUnsynchronizedChanges !=
            list.hasUnsynchronizedChanges) {
          throw Exception('List state mismatch after save for list ${list.id}');
        }
      }
    } catch (e) {
      print('Error saving all lists: $e');
      rethrow;
    }
  }

  Future<List<UserList>> loadLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('lists');

      if (jsonString == null) {
        print('No lists found in SharedPreferences');
        return [];
      }

      print('Loading lists from SharedPreferences');
      print('JSON data: $jsonString');

      final jsonList = jsonDecode(jsonString) as List;
      final lists = jsonList
          .map((json) => UserList.fromJson(json as Map<String, dynamic>))
          .toList();

      print('Loaded ${lists.length} lists from SharedPreferences');
      for (var list in lists) {
        print(
            'List ${list.id} has unsynchronized changes: ${list.hasUnsynchronizedChanges}');
      }

      return lists;
    } catch (e) {
      print('Error loading lists from SharedPreferences: $e');
      return [];
    }
  }

  Future<UserList?> loadList(String id) async {
    try {
      final lists = await loadLists();
      final list = lists.firstWhere((l) => l.id == id);
      print('Loaded list ${list.id} from SharedPreferences');
      print(
          'List has unsynchronized changes: ${list.hasUnsynchronizedChanges}');
      return list;
    } catch (e) {
      print('Error loading list $id from SharedPreferences: $e');
      return null;
    }
  }

  Future<void> deleteList(String listId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lists = await loadLists();
      lists.removeWhere((l) => l.id == listId);

      // Save to SharedPreferences
      final jsonList = lists.map((l) => l.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      print('Saving lists after deletion to SharedPreferences: $jsonString');

      final success = await prefs.setString(_listsKey, jsonString);
      if (!success) {
        throw Exception('Failed to save to SharedPreferences after deletion');
      }

      // Verify the save
      final savedJson = prefs.getString(_listsKey);
      if (savedJson == null) {
        throw Exception('Failed to verify save after deletion - no data found');
      }
      print('Verified saved data after deletion: $savedJson');
    } catch (e) {
      print('Error deleting list $listId: $e');
      rethrow;
    }
  }
}
