/// Maps a row from the `photo_requirements` catalog table (migration 013).
/// Note: id is bigint (int in Dart) — photo_requirements.id, not a uuid text.
class PhotoRequirement {
  final int id;
  final String category; // 'exterior' | 'interior' | 'tyres'
  final String slotKey; // stable machine key, e.g. 'front', 'odometer'
  final String label; // display label, e.g. 'Front', 'Odometer Image'
  final String appliesTo; // 'individual' | 'dealer'
  final int sortOrder;

  const PhotoRequirement({
    required this.id,
    required this.category,
    required this.slotKey,
    required this.label,
    required this.appliesTo,
    required this.sortOrder,
  });

  factory PhotoRequirement.fromJson(Map<String, dynamic> json) {
    return PhotoRequirement(
      id: (json['id'] as num).toInt(),
      category: json['category'] as String,
      slotKey: json['slot_key'] as String,
      label: json['label'] as String,
      appliesTo: json['applies_to'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  /// True if this shot is mandatory for the given account type.
  /// Individual-tier rows are mandatory for everyone; dealer-tier rows
  /// are mandatory only for dealer accounts (optional/recommended for
  /// individual sellers).
  bool isMandatoryFor(String accountType) {
    if (appliesTo == 'individual') return true;
    return accountType == 'dealer';
  }
}

enum PhotoCategory { exterior, interior, tyres, features, highlights }

extension PhotoCategoryX on PhotoCategory {
  String get key => switch (this) {
        PhotoCategory.exterior => 'exterior',
        PhotoCategory.interior => 'interior',
        PhotoCategory.tyres => 'tyres',
        PhotoCategory.features => 'features',
        PhotoCategory.highlights => 'highlights',
      };

  String get label => switch (this) {
        PhotoCategory.exterior => 'Exterior',
        PhotoCategory.interior => 'Interior',
        PhotoCategory.tyres => 'Tyres',
        PhotoCategory.features => 'Features',
        PhotoCategory.highlights => 'Highlights',
      };
}
