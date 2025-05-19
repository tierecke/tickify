import 'base_item.dart';

/// Represents an item within a list that can be either a category (with children)
/// or a leaf item (without children).
///
/// Each item can:
/// * Be marked as done/undone
/// * Be archived/unarchived
/// * Contain child items (if it's a category)
/// * Track its parent (if it's not a root item)
class ListItem extends BaseItem {
  /// Unique identifier for the item
  final String id;

  /// ID of the parent item. Null if this is a root item
  final String? parentId;

  /// Whether the item is marked as done (e.g., packed, purchased, completed)
  bool isDone;

  /// Whether the item is archived
  /// Archived items are typically hidden from the main view but preserved for future use
  bool isArchived;

  /// List of child items if this item is a category
  /// Empty list if this is a leaf item
  List<ListItem> children;

  /// Creates a new [ListItem] with the given properties.
  ///
  /// Required parameters:
  /// * [name]: Display name of the item
  /// * [icon]: Emoji icon for the item
  /// * [id]: Unique identifier
  ///
  /// Optional parameters:
  /// * [parentId]: ID of parent item (null for root items)
  /// * [isDone]: Whether item is completed (defaults to false)
  /// * [isArchived]: Whether item is archived (defaults to false)
  /// * [children]: List of child items (defaults to empty list)
  /// * Timestamp parameters inherited from [BaseItem]
  ListItem({
    required String name,
    required String icon,
    required this.id,
    this.parentId,
    this.isDone = false,
    this.isArchived = false,
    this.children = const [],
    DateTime? createdAt,
  }) : super(
          name: name,
          icon: icon,
          createdAt: createdAt,
        );

  /// Whether this item is a category (has children) or a leaf item
  bool get isCategory => children.isNotEmpty;

  /// Toggles the done status of the item
  void toggleDone() {
    isDone = !isDone;
  }

  /// Toggles the archived status of the item
  void toggleArchived() {
    isArchived = !isArchived;
  }

  /// Converts the item and all its children to a JSON map for persistence
  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'id': id,
        'parentId': parentId,
        'isDone': isDone,
        'isArchived': isArchived,
        'children': children.map((child) => child.toJson()).toList(),
      };

  /// Creates a [ListItem] from a JSON map, including all its children
  ///
  /// This factory constructor is used when deserializing stored data
  factory ListItem.fromJson(Map<String, dynamic> json) {
    print('Deserializing ListItem from JSON: \\${json}');
    var item = ListItem(
      name: json['name'] as String,
      icon: json['icon'] as String,
      id: json['id'] as String,
      parentId: json['parentId'] as String?,
      isDone: json['isDone'] as bool,
      isArchived: json['isArchived'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

    if (json['children'] != null) {
      item.children = (json['children'] as List)
          .map((child) => ListItem.fromJson(child as Map<String, dynamic>))
          .toList();
    }
    print('Created ListItem: \\${item.toJson()}');
    return item;
  }
}
