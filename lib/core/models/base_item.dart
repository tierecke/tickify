/// Base class for all items in the application, providing common properties and functionality
/// for both lists and list items.
///
/// This class implements the basic properties that all items share:
/// * A name for display
/// * An emoji icon for visual representation
/// * Timestamps for creation, modification, and access
class BaseItem {
  /// The display name of the item
  final String name;

  /// Unicode emoji character used as the item's icon
  final String icon; // Unicode emoji character

  /// Timestamp when the item was created
  final DateTime createdAt;

  /// Timestamp of the last modification to the item
  DateTime lastModifiedAt;

  /// Timestamp of the last time the item was accessed
  DateTime lastAccessedAt;

  /// Creates a new [BaseItem] with the given properties.
  ///
  /// If timestamps are not provided, they default to the current time.
  /// [name] and [icon] are required parameters.
  BaseItem({
    required this.name,
    required this.icon,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
    DateTime? lastAccessedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastModifiedAt = lastModifiedAt ?? DateTime.now(),
        lastAccessedAt = lastAccessedAt ?? DateTime.now();

  /// Updates the [lastAccessedAt] timestamp to the current time
  void updateLastAccessed() {
    lastAccessedAt = DateTime.now();
  }

  /// Updates the [lastModifiedAt] timestamp to the current time
  void updateLastModified() {
    lastModifiedAt = DateTime.now();
  }

  /// Converts the item to a JSON map for persistence
  Map<String, dynamic> toJson() => {
        'name': name,
        'icon': icon,
        'createdAt': createdAt.toIso8601String(),
        'lastModifiedAt': lastModifiedAt.toIso8601String(),
        'lastAccessedAt': lastAccessedAt.toIso8601String(),
      };

  /// Creates a [BaseItem] from a JSON map
  ///
  /// This factory constructor is used when deserializing stored data
  factory BaseItem.fromJson(Map<String, dynamic> json) => BaseItem(
        name: json['name'] as String,
        icon: json['icon'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastModifiedAt: DateTime.parse(json['lastModifiedAt'] as String),
        lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
      );
}
