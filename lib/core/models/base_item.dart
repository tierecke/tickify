/// Base class for all items in the application, providing common properties and functionality
/// for both lists and list items.
///
/// This class implements the basic properties that all items share:
/// * A name for display
/// * An emoji icon for visual representation
/// * Timestamp for creation
class BaseItem {
  /// The display name of the item
  final String name;

  /// Unicode emoji character used as the item's icon
  final String icon; // Unicode emoji character

  /// Timestamp when the item was created
  final DateTime createdAt;

  /// Creates a new [BaseItem] with the given properties.
  ///
  /// If timestamp is not provided, it defaults to the current time.
  /// [name] and [icon] are required parameters.
  BaseItem({
    required this.name,
    required this.icon,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Converts the item to a JSON map for persistence
  Map<String, dynamic> toJson() => {
        'name': name,
        'icon': icon,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Creates a [BaseItem] from a JSON map
  ///
  /// This factory constructor is used when deserializing stored data
  factory BaseItem.fromJson(Map<String, dynamic> json) => BaseItem(
        name: json['name'] as String,
        icon: json['icon'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
