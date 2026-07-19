import '../../../core/config/supabase_config.dart';
import '../models/vehicle_draft.dart';

/// Handles creating and publishing a vehicle listing.
///
/// Flow (post photo-checklist redesign):
///  1. createDraft() — called once, when the user reaches the Photos step.
///     Inserts a `vehicles` row with status 'draft' and returns its id.
///  2. updateDraftFields() — called again if the user navigates back and
///     re-edits Details/Price after the draft row already exists, keeping
///     the row in sync before publishing.
///  3. Photos/features are uploaded directly against that vehicleId by the
///     listing capture checklist (ListingCaptureNotifier) — not staged here.
///  4. publishDraft() — called from the Preview step's Publish button.
///     Flips status to 'published'; the enforce_listing_complete_before_publish
///     trigger (migration 013) rejects this update if mandatory photos or
///     selected-feature proof photos are still missing.
class SellRepository {
  Future<int> createDraft(String accountId, VehicleDraft draft) async {
    if (!draft.isStep1Complete || !draft.isStep2Complete) {
      throw StateError(
          'Vehicle details and price must be complete before creating a draft');
    }

    final row = await supabase
        .from('vehicles')
        .insert({
          'account_id': accountId,
          'category': draft.category.name,
          'brand_id': draft.brandId,
          'model_id': draft.modelId,
          'variant': draft.variant,
          'year': draft.year,
          'fuel_type': draft.fuelType!.name,
          'transmission': draft.transmission!.name,
          'km_driven': draft.kmDriven ?? 0,
          'owner_number': draft.ownerNumber,
          'price': draft.price,
          'description': draft.description,
          'city_id': draft.cityId,
          'registration_number': draft.registrationNumber,
          'status': 'draft',
        })
        .select('id')
        .single();

    return row['id'] as int;
  }

  /// Keeps an already-created draft row in sync if the user goes back and
  /// edits Details/Price after the Photos step was first reached.
  Future<void> updateDraftFields(int vehicleId, VehicleDraft draft) async {
    await supabase.from('vehicles').update({
      'category': draft.category.name,
      'brand_id': draft.brandId,
      'model_id': draft.modelId,
      'variant': draft.variant,
      'year': draft.year,
      'fuel_type': draft.fuelType?.name,
      'transmission': draft.transmission?.name,
      'km_driven': draft.kmDriven ?? 0,
      'owner_number': draft.ownerNumber,
      'price': draft.price,
      'description': draft.description,
      'city_id': draft.cityId,
      'registration_number': draft.registrationNumber,
    }).eq('id', vehicleId);
  }

  /// Flips the draft to published. The DB trigger from migration 013
  /// rejects this if mandatory photos/features are still missing, so
  /// callers should still run listingCaptureProvider's checkCompleteness()
  /// first for a friendly in-app message rather than relying solely on the
  /// raised Postgres exception as the only signal.
  Future<void> publishDraft(int vehicleId) async {
    await supabase
        .from('vehicles')
        .update({'status': 'published'}).eq('id', vehicleId);
  }
}
