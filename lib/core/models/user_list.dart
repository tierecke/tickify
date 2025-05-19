import 'base_item.dart';
import 'list_item.dart';

/// Represents a complete user list containing multiple items organized in a tree structure.
///
/// A UserList is the top-level container that holds all items and provides functionality for:
/// * Managing items (add/remove)
/// * Tracking completion status
/// * Managing archived status
/// * Calculating completion statistics
class UserList extends BaseItem {
  /// Unique identifier for the list
  final String id;

  /// The root-level items in the list
  /// Each item can have its own children, forming a tree structure
  final List<ListItem> items;

  /// Whether the list is archived
  /// Archived lists are typically hidden from the main view but preserved for future use
  bool isArchived;

  /// Creates a new [UserList] with the given properties.
  ///
  /// Required parameters:
  /// * [name]: Display name of the list
  /// * [icon]: Emoji icon for the list
  /// * [id]: Unique identifier
  ///
  /// Optional parameters:
  /// * [items]: Initial list of items (defaults to empty list)
  /// * [isArchived]: Whether list is archived (defaults to false)
  /// * Timestamp parameters inherited from [BaseItem]
  UserList({
    required String name,
    required String icon,
    required this.id,
    this.items = const [],
    this.isArchived = false,
    DateTime? createdAt,
  }) : super(
          name: name,
          icon: icon,
          createdAt: createdAt,
        );

  /// Adds a new item to the list
  void addItem(ListItem item) {
    items.add(item);
  }

  /// Removes an item from the list by its ID
  void removeItem(String itemId) {
    items.removeWhere((item) => item.id == itemId);
  }

  /// Toggles the archived status of the list
  void toggleArchived() {
    isArchived = !isArchived;
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
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'id': id,
        'items': items.map((item) => item.toJson()).toList(),
        'isArchived': isArchived,
      };

  /// Creates a [UserList] from a JSON map, including all its items
  ///
  /// This factory constructor is used when deserializing stored data
  factory UserList.fromJson(Map<String, dynamic> json) {
    var list = UserList(
      name: json['name'] as String,
      icon: json['icon'] as String,
      id: json['id'] as String,
      isArchived: json['isArchived'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

    if (json['items'] != null) {
      list.items.addAll(
        (json['items'] as List)
            .map((item) => ListItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }

    return list;
  }
}
