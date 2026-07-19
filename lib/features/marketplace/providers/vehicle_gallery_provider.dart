import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/photo_requirement.dart';
import '../widgets/vehicle_gallery_viewer.dart';

// ASSUMPTION: matches the Supabase client accessor already used in
// listing_capture_provider.dart. Adjust if your project has a shared
// client provider elsewhere.
final _supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

/// Builds the buyer-facing gallery for a vehicle by joining vehicle_images
/// with photo_requirements (for slot category/label) and feature_tags (for
/// feature-proof photo labels). Flat sequential queries, not an embedded
/// PostgREST join — matches this project's established data-fetching
/// pattern (see Sprint 4 vehicle detail screen).
///
/// NOTE: "Highlights" is deliberately not included here — those are
/// auto-generated text cards from selected features, not real photos, and
/// that rendering hasn't been built yet. Only categories with actual
/// uploaded photos (Exterior, Interior, Features, Tyres) appear.
final vehicleGalleryProvider =
    FutureProvider.family<List<GalleryPhoto>, int>((ref, vehicleId) async {
  final client = ref.read(_supabaseProvider);

  final imagesRes = await client
      .from('vehicle_images')
      .select()
      .eq('vehicle_id', vehicleId)
      .order('sort_order');
  final images = imagesRes as List;
  if (images.isEmpty) return [];

  final requirementsRes = await client.from('photo_requirements').select();
  final requirements = (requirementsRes as List)
      .map((e) => PhotoRequirement.fromJson(e as Map<String, dynamic>))
      .toList();
  final requirementsById = {for (final r in requirements) r.id: r};

  final featureTagsRes = await client.from('feature_tags').select();
  final featureLabelsByKey = {
    for (final f in (featureTagsRes as List))
      (f as Map<String, dynamic>)['key'] as String:
          f['label'] as String,
  };

  final photos = <GalleryPhoto>[];
  for (final row in images) {
    final r = row as Map<String, dynamic>;
    final url = r['image_url'] as String;
    final reqId = r['requirement_id'];
    final featureKey = r['feature_key'] as String?;

    if (reqId != null) {
      final requirement = requirementsById[(reqId as num).toInt()];
      if (requirement == null) continue;
      photos.add(GalleryPhoto(
        url: url,
        label: requirement.label,
        category: switch (requirement.category) {
          'exterior' => PhotoCategory.exterior,
          'interior' => PhotoCategory.interior,
          'tyres' => PhotoCategory.tyres,
          _ => PhotoCategory.exterior,
        },
      ));
    } else if (featureKey != null) {
      photos.add(GalleryPhoto(
        url: url,
        label: featureLabelsByKey[featureKey] ?? featureKey,
        category: PhotoCategory.features,
      ));
    } else {
      // Legacy/freeform photo with no slot or feature link (e.g. a vehicle
      // listed before the structured checklist existed). Show it under
      // Exterior with a generic label rather than dropping it.
      photos.add(GalleryPhoto(
        url: url,
        label: 'Photo',
        category: PhotoCategory.exterior,
      ));
    }
  }

  return photos;
});
