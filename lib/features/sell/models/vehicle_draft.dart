import '../../marketplace/models/vehicle.dart';

/// Mutable-by-replacement draft state for the multi-step Sell Vehicle flow.
///
/// Steps 0-1 (Details, Price/Location) only edit this in-memory draft —
/// nothing touches Supabase yet. Once the user reaches the Photos step, a
/// real `vehicles` row is created with status 'draft' (see
/// SellRepository.createDraft) and its id is stored here as `vehicleId`.
/// From that point on, photos are uploaded directly against that row via
/// the listing capture checklist (ListingCaptureNotifier) — they are no
/// longer staged as XFiles in this draft (the old `images` field is gone).
class VehicleDraft {
  const VehicleDraft({
    this.category = VehicleCategory.car,
    this.brandId,
    this.brandName,
    this.modelId,
    this.modelName,
    this.variant,
    this.year,
    this.fuelType,
    this.transmission,
    this.kmDriven,
    this.price,
    this.description,
    this.cityId,
    this.cityName,
    this.registrationNumber,
    this.vehicleId,
  });

  final VehicleCategory category;
  final int? brandId;
  final String? brandName;
  final int? modelId;
  final String? modelName;
  final String? variant;
  final int? year;
  final FuelType? fuelType;
  final TransmissionType? transmission;
  final int? kmDriven;
  final double? price;
  final String? description;
  final int? cityId;
  final String? cityName;

  /// Private — never shown publicly, kept for verification only.
  final String? registrationNumber;

  /// Set once the draft `vehicles` row exists (on reaching the Photos
  /// step). Null before that.
  final int? vehicleId;

  bool get isStep1Complete =>
      brandId != null &&
      modelId != null &&
      year != null &&
      fuelType != null &&
      transmission != null;

  bool get isStep2Complete => price != null && price! > 0 && cityId != null;

  /// The draft row exists — actual photo/feature completeness is tracked
  /// server-side via is_listing_complete() / listingCaptureProvider, not
  /// here. The Photos step's own Next button gates on that provider state
  /// directly rather than on this getter.
  bool get isStep3Complete => vehicleId != null;

  bool get isReadyToPublish =>
      isStep1Complete && isStep2Complete && isStep3Complete;

  String get title => [brandName, modelName, variant]
      .where((s) => s != null && s.isNotEmpty)
      .join(' ');

  VehicleDraft copyWith({
    VehicleCategory? category,
    int? brandId,
    String? brandName,
    int? modelId,
    String? modelName,
    String? variant,
    int? year,
    FuelType? fuelType,
    TransmissionType? transmission,
    int? kmDriven,
    double? price,
    String? description,
    int? cityId,
    String? cityName,
    String? registrationNumber,
    int? vehicleId,
  }) {
    return VehicleDraft(
      category: category ?? this.category,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
      variant: variant ?? this.variant,
      year: year ?? this.year,
      fuelType: fuelType ?? this.fuelType,
      transmission: transmission ?? this.transmission,
      kmDriven: kmDriven ?? this.kmDriven,
      price: price ?? this.price,
      description: description ?? this.description,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      vehicleId: vehicleId ?? this.vehicleId,
    );
  }
}
