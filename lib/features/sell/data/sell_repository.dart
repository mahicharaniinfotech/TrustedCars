import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../models/vehicle_draft.dart';

/// Handles publishing a vehicle listing -- the write side of the
/// marketplace, kept separate from VehicleRepository (which only reads)
/// the same way AuthRepository/AccountRepository are split by concern.
class SellRepository {
  Future<int> publishVehicle(String accountId, VehicleDraft draft) async {
    if (!draft.isReadyToPublish) {
      throw StateError('Draft is missing required fields');
    }

    final vehicleRow = await supabase
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
          'price': draft.price,
          'description': draft.description,
          'city_id': draft.cityId,
          'status': 'published',
        })
        .select('id')
        .single();

    final vehicleId = vehicleRow['id'] as int;

    // Images are uploaded after the vehicle row exists, since the storage
    // path includes the vehicle id (see migration 008's path convention).
    for (var i = 0; i < draft.images.length; i++) {
      final image = draft.images[i];
      final bytes = await image.readAsBytes();
      final ext = image.name.contains('.') ? image.name.split('.').last : 'jpg';
      final path = '$accountId/$vehicleId/${DateTime.now().millisecondsSinceEpoch}_$i.$ext';

      try {
        await supabase.storage.from('vehicle-images').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );

        final publicUrl = supabase.storage.from('vehicle-images').getPublicUrl(path);

        await supabase.from('vehicle_images').insert({
          'vehicle_id': vehicleId,
          'image_url': publicUrl,
          'sort_order': i,
          'is_primary': i == 0,
        });
      } catch (e) {
        // One failed image shouldn't block the whole listing -- the
        // vehicle is already published; log and continue with the rest.
        // ignore: avoid_print
        print('Image upload failed for index $i: $e');
      }
    }

    return vehicleId;
  }
}
