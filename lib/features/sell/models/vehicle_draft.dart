import '../../marketplace/models/vehicle.dart';

/// A km-driven range bucket, matching the reference flow's 10k-wide bands.
/// The seller picks a bucket; we store its representative value in
/// VehicleDraft.kmDriven (upper bound, so the number shown is never an
/// understatement of actual mileage). The mandatory Odometer photo in the
/// listing checklist (see photo_requirements catalog) is what actually
/// confirms the real reading — the bucket is just a low-friction way to
/// answer at listing time.
class KmRangeBucket {
  final String label;
  final int representativeKm;

  const KmRangeBucket(this.label, this.representativeKm);

  static const List<KmRangeBucket> all = [
    KmRangeBucket('0 Km - 10,000 Km', 10000),
    KmRangeBucket('10,000 Km - 20,000 Km', 20000),
    KmRangeBucket('20,000 Km - 30,000 Km', 30000),
    KmRangeBucket('30,000 Km - 40,000 Km', 40000),
    KmRangeBucket('40,000 Km - 50,000 Km', 50000),
    KmRangeBucket('50,000 Km - 60,000 Km', 60000),
    KmRangeBucket('60,000 Km - 70,000 Km', 70000),
    KmRangeBucket('70,000 Km - 80,000 Km', 80000),
    KmRangeBucket('80,000 Km - 90,000 Km', 90000),
    KmRangeBucket('90,000 Km - 100,000 Km', 100000),
    KmRangeBucket('100,000+ Km', 150000),
  ];
}

/// Ownership history options — 1st through 4th owner, plus a "5th or
/// beyond" bucket. Maps to vehicles.owner_number (migration 015).
class OwnershipOption {
  final String label;
  final int ownerNumber;

  const OwnershipOption(this.label, this.ownerNumber);

  static const List<OwnershipOption> all = [
    OwnershipOption('1st owner', 1),
    OwnershipOption('2nd owner', 2),
    OwnershipOption('3rd owner', 3),
    OwnershipOption('4th owner', 4),
    OwnershipOption('5th owner or beyond', 5),
  ];
}

/// Mutable-by-replacement draft state for the multi-step Sell Vehicle flow.
///
/// Steps 0-1 (Details, Price) only edit this in-memory draft — nothing
/// touches Supabase yet. Once the user reaches the Photos step, a real
/// `vehicles` row is created with status 'draft' (see
/// SellRepository.createDraft) and its id is stored here as `vehicleId`.
/// From that point on, photos are uploaded directly against that row via
/// the listing capture checklist (ListingCaptureNotifier) — they are no
/// longer staged as XFiles in this draft.
///
/// NOTE: cityId/cityName are now gathered during the Step 0 Details wizard
/// (one-question-per-screen, matching the reference flow) rather than in
/// Step 1 (Price) — Step 1 is now just price, description, and the private
/// registration number.
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
    this.ownerNumber,
    this.kmDriven,
    this.cityId,
    this.cityName,
    this.price,
    this.description,
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

  /// 1-4 = exact owner count, 5 = "5th owner or beyond".
  final int? ownerNumber;

  /// Representative km value from the selected range bucket (see
  /// KmRangeBucket) — not necessarily an exact odometer reading. The
  /// mandatory Odometer photo confirms the real number.
  final int? kmDriven;

  final int? cityId;
  final String? cityName;

  final double? price;
  final String? description;

  /// Private — never shown publicly, kept for verification only.
  final String? registrationNumber;

  /// Set once the draft `vehicles` row exists (on reaching the Photos
  /// step). Null before that.
  final int? vehicleId;

  /// All seven Details-wizard questions answered.
  bool get isStep1Complete =>
      brandId != null &&
      modelId != null &&
      year != null &&
      fuelType != null &&
      transmission != null &&
      ownerNumber != null &&
      kmDriven != null &&
      cityId != null;

  bool get isStep2Complete => price != null && price! > 0;

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
    int? ownerNumber,
    int? kmDriven,
    int? cityId,
    String? cityName,
    double? price,
    String? description,
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
      ownerNumber: ownerNumber ?? this.ownerNumber,
      kmDriven: kmDriven ?? this.kmDriven,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      price: price ?? this.price,
      description: description ?? this.description,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      vehicleId: vehicleId ?? this.vehicleId,
    );
  }
}
