import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/photo_requirement.dart';
import '../models/feature_tag.dart';

// ASSUMPTION: adjust to match your actual Supabase client provider name
// if you already have one wired elsewhere (e.g. in kyc_providers.dart).
final _supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

// ASSUMPTION: storage bucket name used for vehicle images in Sprint 5.
// Update this constant only if your bucket is named differently.
const _kVehicleImagesBucket = 'vehicle-images';

class ListingCaptureState {
  final List<PhotoRequirement> requirements;
  final List<FeatureTag> featureTags;
  final String accountType; // 'individual' | 'dealer'

  /// photo_requirements.id -> public URL of the uploaded photo
  final Map<int, String> slotPhotos;

  /// feature_tags.key -> public URL of the uploaded proof photo
  final Map<String, String> featurePhotos;

  /// Features the seller has checked as present on this vehicle
  final Set<String> selectedFeatures;

  final bool isUploading;
  final bool isComplete;
  final List<String> missingLabels;

  const ListingCaptureState({
    this.requirements = const [],
    this.featureTags = const [],
    this.accountType = 'individual',
    this.slotPhotos = const {},
    this.featurePhotos = const {},
    this.selectedFeatures = const {},
    this.isUploading = false,
    this.isComplete = false,
    this.missingLabels = const [],
  });

  ListingCaptureState copyWith({
    List<PhotoRequirement>? requirements,
    List<FeatureTag>? featureTags,
    String? accountType,
    Map<int, String>? slotPhotos,
    Map<String, String>? featurePhotos,
    Set<String>? selectedFeatures,
    bool? isUploading,
    bool? isComplete,
    List<String>? missingLabels,
  }) {
    return ListingCaptureState(
      requirements: requirements ?? this.requirements,
      featureTags: featureTags ?? this.featureTags,
      accountType: accountType ?? this.accountType,
      slotPhotos: slotPhotos ?? this.slotPhotos,
      featurePhotos: featurePhotos ?? this.featurePhotos,
      selectedFeatures: selectedFeatures ?? this.selectedFeatures,
      isUploading: isUploading ?? this.isUploading,
      isComplete: isComplete ?? this.isComplete,
      missingLabels: missingLabels ?? this.missingLabels,
    );
  }

  List<PhotoRequirement> requirementsFor(PhotoCategory category) {
    final catKey = category.key;
    return requirements.where((r) => r.category == catKey).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  /// Mandatory slots for this seller's account type, still unfilled.
  int get remainingMandatoryCount {
    final unfilled = requirements.where(
      (r) => r.isMandatoryFor(accountType) && !slotPhotos.containsKey(r.id),
    );
    final unfilledFeatures = selectedFeatures.where(
      (k) => !featurePhotos.containsKey(k),
    );
    return unfilled.length + unfilledFeatures.length;
  }

  int get totalMandatoryCount {
    return requirements.where((r) => r.isMandatoryFor(accountType)).length +
        selectedFeatures.length;
  }

  int get totalPhotoCount => slotPhotos.length + featurePhotos.length;

  /// A representative photo for preview purposes — prefers the Exterior
  /// "front" shot (the natural cover image), falling back to whatever's
  /// been uploaded first if that specific slot isn't filled yet.
  String? get coverPhotoUrl {
    PhotoRequirement? frontReq;
    for (final r in requirements) {
      if (r.category == 'exterior' && r.slotKey == 'front') {
        frontReq = r;
        break;
      }
    }
    if (frontReq != null && slotPhotos.containsKey(frontReq.id)) {
      return slotPhotos[frontReq.id];
    }
    if (slotPhotos.isNotEmpty) return slotPhotos.values.first;
    if (featurePhotos.isNotEmpty) return featurePhotos.values.first;
    return null;
  }
}

/// NOTE: deliberately NOT a .family provider. Different Riverpod versions
/// handle family notifiers differently (some via a FamilyAsyncNotifier base
/// class, newer ones via an `arg` getter) and guessing wrong breaks the
/// build. Instead this is a plain AsyncNotifierProvider; the screen calls
/// loadVehicle(vehicleId) once when it opens, which works identically
/// across versions.
class ListingCaptureNotifier extends AsyncNotifier<ListingCaptureState> {
  int? _vehicleId;

  int get _requireVehicleId {
    final id = _vehicleId;
    if (id == null) {
      throw StateError(
          'loadVehicle(vehicleId) must be called before using ListingCaptureNotifier');
    }
    return id;
  }

  @override
  Future<ListingCaptureState> build() async {
    // Empty placeholder until loadVehicle() is called by the screen.
    return const ListingCaptureState();
  }

  /// Call once (e.g. in the screen's initState) with the vehicle being
  /// listed. Populates catalogs, account type, and any existing uploads.
  Future<void> loadVehicle(int vehicleId) async {
    _vehicleId = vehicleId;
    state = const AsyncLoading();
    try {
      final result = await _fetch(vehicleId);
      state = AsyncData(result);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<ListingCaptureState> _fetch(int vehicleId) async {
    final client = ref.read(_supabaseProvider);

    // 1. Catalogs
    final requirementsRes =
        await client.from('photo_requirements').select().order('sort_order');
    final featureTagsRes =
        await client.from('feature_tags').select().order('sort_order');

    final requirements = (requirementsRes as List)
        .map((e) => PhotoRequirement.fromJson(e as Map<String, dynamic>))
        .toList();
    final featureTags = (featureTagsRes as List)
        .map((e) => FeatureTag.fromJson(e as Map<String, dynamic>))
        .toList();

    // 2. Seller account type (drives which shots are mandatory).
    // vehicles.account_id -> accounts.id (both text); vehicles.id is bigint.
    final vehicleRow = await client
        .from('vehicles')
        .select('account_id')
        .eq('id', vehicleId)
        .single();
    final accountId = vehicleRow['account_id'] as String;
    final accountRow = await client
        .from('accounts')
        .select('account_type')
        .eq('id', accountId)
        .single();
    final accountType = accountRow['account_type'] as String? ?? 'individual';

    // 3. Existing uploads for this vehicle (resuming a draft), read from the
    // existing vehicle_images table extended with requirement_id/feature_key.
    final existingPhotos = await client
        .from('vehicle_images')
        .select()
        .eq('vehicle_id', vehicleId);
    final slotPhotos = <int, String>{};
    final featurePhotos = <String, String>{};
    for (final row in (existingPhotos as List)) {
      final r = row as Map<String, dynamic>;
      final url = r['image_url'] as String;
      final reqId = r['requirement_id'];
      final featureKey = r['feature_key'] as String?;
      if (reqId != null) {
        slotPhotos[(reqId as num).toInt()] = url;
      } else if (featureKey != null) {
        featurePhotos[featureKey] = url;
      }
    }

    final existingFeatures = await client
        .from('listing_features')
        .select('feature_key')
        .eq('vehicle_id', vehicleId);
    final selectedFeatures = (existingFeatures as List)
        .map((e) => (e as Map<String, dynamic>)['feature_key'] as String)
        .toSet();

    final initial = ListingCaptureState(
      requirements: requirements,
      featureTags: featureTags,
      accountType: accountType,
      slotPhotos: slotPhotos,
      featurePhotos: featurePhotos,
      selectedFeatures: selectedFeatures,
    );

    return initial.copyWith(
      isComplete: initial.remainingMandatoryCount == 0,
    );
  }

  Future<void> toggleFeature(String featureKey, bool selected) async {
    final vehicleId = _requireVehicleId;
    final current = state.value;
    if (current == null) return;
    final client = ref.read(_supabaseProvider);

    final updatedSelected = <String>{...current.selectedFeatures};
    if (selected) {
      updatedSelected.add(featureKey);
      await client.from('listing_features').upsert({
        'vehicle_id': vehicleId,
        'feature_key': featureKey,
      }, onConflict: 'vehicle_id,feature_key');

      state = AsyncData(current.copyWith(
        selectedFeatures: updatedSelected,
        isComplete: current
                .copyWith(selectedFeatures: updatedSelected)
                .remainingMandatoryCount ==
            0,
      ));
    } else {
      updatedSelected.remove(featureKey);
      await client
          .from('listing_features')
          .delete()
          .eq('vehicle_id', vehicleId)
          .eq('feature_key', featureKey);
      // Also drop any proof photo tied to a de-selected feature.
      await client
          .from('vehicle_images')
          .delete()
          .eq('vehicle_id', vehicleId)
          .eq('feature_key', featureKey);
      final updatedFeaturePhotos = <String, String>{...current.featurePhotos}
        ..remove(featureKey);

      final next = current.copyWith(
        selectedFeatures: updatedSelected,
        featurePhotos: updatedFeaturePhotos,
      );
      state = AsyncData(next.copyWith(
        isComplete: next.remainingMandatoryCount == 0,
      ));
    }
  }

  /// Upload a photo for a mandatory slot (requirement) or a feature proof.
  /// Pass exactly one of [requirement] or [featureKey].
  Future<void> uploadPhoto({
    PhotoRequirement? requirement,
    String? featureKey,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    assert((requirement == null) != (featureKey == null),
        'Pass exactly one of requirement or featureKey');
    final vehicleId = _requireVehicleId;
    final current = state.value;
    if (current == null) return;

    state = AsyncData(current.copyWith(isUploading: true));
    final client = ref.read(_supabaseProvider);

    final slotOrFeatureKey = requirement?.slotKey ?? featureKey!;
    final storagePath =
        '$vehicleId/${requirement != null ? "slot" : "feature"}_$slotOrFeatureKey.$fileExtension';

    try {
      await client.storage.from(_kVehicleImagesBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final url =
          client.storage.from(_kVehicleImagesBucket).getPublicUrl(storagePath);

      // vehicle_images has partial unique indexes (not a single composite
      // unique constraint covering both nullable columns), so we do an
      // explicit check-then-write instead of upsert(onConflict: ...).
      final Map<String, Object> matchFilter = requirement != null
          ? {'requirement_id': requirement.id}
          : {'feature_key': featureKey!};

      final existing = await client
          .from('vehicle_images')
          .select('id')
          .eq('vehicle_id', vehicleId)
          .match(matchFilter)
          .maybeSingle();

      if (existing != null) {
        await client
            .from('vehicle_images')
            .update({'image_url': url}).eq('id', existing['id']);
      } else {
        await client.from('vehicle_images').insert({
          'vehicle_id': vehicleId,
          'requirement_id': requirement?.id,
          'feature_key': featureKey,
          'image_url': url,
          'sort_order': 0,
          'is_primary': false,
        });
      }

      final updatedSlotPhotos = <int, String>{...current.slotPhotos};
      final updatedFeaturePhotos = <String, String>{...current.featurePhotos};
      if (requirement != null) {
        updatedSlotPhotos[requirement.id] = url;
      } else {
        updatedFeaturePhotos[featureKey!] = url;
      }

      final next = current.copyWith(
        slotPhotos: updatedSlotPhotos,
        featurePhotos: updatedFeaturePhotos,
        isUploading: false,
      );
      state = AsyncData(next.copyWith(
        isComplete: next.remainingMandatoryCount == 0,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(isUploading: false));
      rethrow;
    }
  }

  /// Server-side authoritative check before allowing publish, calling the
  /// is_listing_complete() Postgres function from migration 013.
  Future<({bool complete, int missingCount, List<String> missingLabels})>
      checkCompleteness() async {
    final vehicleId = _requireVehicleId;
    final client = ref.read(_supabaseProvider);
    final res = await client.rpc('is_listing_complete', params: {
      'p_vehicle_id': vehicleId,
    });
    final row = (res as List).first as Map<String, dynamic>;
    final missing = (row['missing_labels'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return (
      complete: row['complete'] as bool? ?? false,
      missingCount: (row['missing_count'] as num?)?.toInt() ?? 0,
      missingLabels: missing,
    );
  }
}

final listingCaptureProvider =
    AsyncNotifierProvider<ListingCaptureNotifier, ListingCaptureState>(
  ListingCaptureNotifier.new,
);
