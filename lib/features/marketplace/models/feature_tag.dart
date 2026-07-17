/// Maps a row from the `feature_tags` catalog table (migration 013).
class FeatureTag {
  final String key;
  final String label;
  final String groupName; // 'safety' | 'comfort' | 'tech'
  final String? iconName;
  final bool isHighlightEligible;
  final int sortOrder;

  const FeatureTag({
    required this.key,
    required this.label,
    required this.groupName,
    this.iconName,
    required this.isHighlightEligible,
    required this.sortOrder,
  });

  factory FeatureTag.fromJson(Map<String, dynamic> json) {
    return FeatureTag(
      key: json['key'] as String,
      label: json['label'] as String,
      groupName: json['group_name'] as String,
      iconName: json['icon_name'] as String?,
      isHighlightEligible: json['is_highlight_eligible'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
