import 'base_item.dart';
import 'list_item.dart';

/// Represents a complete user list containing multiple items organized in a tree structure.
///
/// A UserList is the top-level container that holds all items and provides functionality for:
/// * Managing items (add/remove)
/// * Tracking completion status
/// * Managing archived status
/// * Calculating completion statistics
class SharedUser {
  final String userId;
  final String permission; // e.g. 'read', 'write'

  SharedUser({required this.userId, required this.permission});

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'permission': permission,
      };

  factory SharedUser.fromJson(Map<String, dynamic> json) => SharedUser(
        userId: json['userId'] as String,
        permission: json['permission'] as String,
      );
}

class UserList extends BaseItem {
  /// Unique identifier for the list
  final String id;

  /// The root-level items in the list
  /// Each item can have its own children, forming a tree structure
  final List<ListItem> items;

  /// The display name of the list (now mutable)
  @override
  String name;

  /// Unicode emoji character used as the list's icon (now mutable)
  @override
  String icon;

  /// The owner user ID (nullable for local lists)
  String? ownerId;

  /// List of shared users (userId + permission)
  final List<SharedUser> shared;

  /// Whether the list is archived
  /// Archived lists are typically hidden from the main view but preserved for future use
  bool isArchived;

  /// Timestamp when the list was last opened
  DateTime lastOpenedAt;

  /// Timestamp when the list was last modified
  DateTime lastModifiedAt;

  /// Whether the list has unsynchronized changes
  bool hasUnsynchronizedChanges;

  /// Creates a new [UserList] with the given properties.
  ///
  /// Required parameters:
  /// * [name]: Display name of the list
  /// * [icon]: Emoji icon for the list
  /// * [id]: Unique identifier
  ///
  /// Optional parameters:
  /// * [items]: Initial list of items (defaults to empty list)
  /// * [ownerId]: The owner user ID (nullable for local lists)
  /// * [shared]: List of shared users (userId + permission)
  /// * [isArchived]: Whether list is archived (defaults to false)
  /// * [createdAt]: Creation timestamp (defaults to current time)
  /// * [lastOpenedAt]: Last opened timestamp (defaults to current time)
  /// * [lastModifiedAt]: Last modified timestamp (defaults to current time)
  /// * [hasUnsynchronizedChanges]: Whether the list has unsynchronized changes (defaults to false)
  UserList({
    required this.name,
    required this.icon,
    required this.id,
    List<ListItem>? items,
    this.ownerId,
    List<SharedUser>? shared,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? lastOpenedAt,
    DateTime? lastModifiedAt,
    bool? hasUnsynchronizedChanges,
  })  : items = items ?? <ListItem>[],
        shared = shared ?? <SharedUser>[],
        lastOpenedAt = lastOpenedAt ?? DateTime.now(),
        lastModifiedAt = lastModifiedAt ?? DateTime.now(),
        hasUnsynchronizedChanges = hasUnsynchronizedChanges ?? false,
        super(
          name: name,
          icon: icon,
          createdAt: createdAt,
        );

  /// Updates the last opened timestamp to the current time
  void updateLastOpened() {
    lastOpenedAt = DateTime.now();
  }

  /// Updates the last modified timestamp to the current time
  void updateLastModified() {
    lastModifiedAt = DateTime.now();
    hasUnsynchronizedChanges = true;
    print(
        'List ${id} marked as modified. hasUnsynchronizedChanges: $hasUnsynchronizedChanges');
  }

  /// Marks the list as synchronized
  void markAsSynchronized() {
    hasUnsynchronizedChanges = false;
    print(
        'List ${id} marked as synchronized. hasUnsynchronizedChanges: $hasUnsynchronizedChanges');
  }

  /// Adds a new item to the list
  void addItem(ListItem item) {
    items.add(item);
    updateLastModified();
  }

  /// Removes an item from the list by its ID
  void removeItem(String itemId) {
    items.removeWhere((item) => item.id == itemId);
    updateLastModified();
  }

  /// Toggles the archived status of the list
  void toggleArchived() {
    isArchived = !isArchived;
    updateLastModified();
  }

  /// Calculates the percentage of completed items in the list
  ///
  /// Returns a value between 0.0 and 100.0
  /// Returns 0.0 if the list is empty
  double get completionPercentage {
    if (items.isEmpty) return 0.0;

    int totalItems = _countAllItems(items);
    int completedItems = _countCompletedItems(items);

    return completedItems / totalItems * 100;
  }

  /// Recursively counts all items in the list, including items in subcategories
  ///
  /// Only counts leaf items (non-categories)
  int _countAllItems(List<ListItem> items) {
    int count = 0;
    for (var item in items) {
      if (item.isCategory) {
        count += _countAllItems(item.children);
      } else {
        count++;
      }
    }
    return count;
  }

  /// Recursively counts all completed items in the list, including items in subcategories
  ///
  /// Only counts leaf items (non-categories) that are marked as done
  int _countCompletedItems(List<ListItem> items) {
    int count = 0;
    for (var item in items) {
      if (item.isCategory) {
        count += _countCompletedItems(item.children);
      } else if (item.isDone) {
        count++;
      }
    }
    return count;
  }

  /// Converts the list and all its items to a JSON map for persistence
  @override
  Map<String, dynamic> toJson() {
    final json = {
      ...super.toJson(),
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'ownerId': ownerId,
      'shared': shared.map((s) => s.toJson()).toList(),
      'isArchived': isArchived,
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt.toIso8601String(),
      'hasUnsynchronizedChanges': hasUnsynchronizedChanges,
    };
    print(
        'Converting list ${id} to JSON. hasUnsynchronizedChanges: $hasUnsynchronizedChanges');
    print('JSON data: $json');
    return json;
  }

  /// Creates a [UserList] from a JSON map, including all its items
  ///
  /// This factory constructor is used when deserializing stored data
  factory UserList.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing JSON for list: ${json['id']}');
      print('JSON data: $json');

      final items = (json['items'] as List<dynamic>?)
          ?.map((item) => ListItem.fromJson(item as Map<String, dynamic>))
          .toList();
      final shared = (json['shared'] as List<dynamic>?)
          ?.map((s) => SharedUser.fromJson(s as Map<String, dynamic>))
          .toList();

      // Explicitly handle hasUnsynchronizedChanges
      final hasUnsynchronizedChanges =
          json['hasUnsynchronizedChanges'] as bool?;
      print('Parsed hasUnsynchronizedChanges: $hasUnsynchronizedChanges');

      final list = UserList(
        name: json['name'] as String,
        icon: json['icon'] as String,
        id: json['id'] as String,
        items: items ?? [],
        ownerId: json['ownerId'] as String?,
        shared: shared ?? [],
        isArchived: json['isArchived'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastOpenedAt: DateTime.parse(json['lastOpenedAt'] as String),
        lastModifiedAt: DateTime.parse(json['lastModifiedAt'] as String),
        hasUnsynchronizedChanges: hasUnsynchronizedChanges,
      );

      print(
          'Created list ${list.id} with hasUnsynchronizedChanges: ${list.hasUnsynchronizedChanges}');
      return list;
    } catch (e) {
      print('Error parsing UserList from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}
