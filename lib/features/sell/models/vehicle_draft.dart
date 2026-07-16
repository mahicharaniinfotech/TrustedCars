import 'package:image_picker/image_picker.dart';
import '../../marketplace/models/vehicle.dart';

/// Mutable-by-replacement draft state for the multi-step Sell Vehicle flow.
/// Every step reads/writes this via SellDraftNotifier -- nothing is
/// persisted to Supabase until the final Publish action on the Preview step.
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
    this.images = const [],
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
  final List<XFile> images;

  bool get isStep1Complete =>
      brandId != null && modelId != null && year != null && fuelType != null && transmission != null;

  bool get isStep2Complete => price != null && price! > 0 && cityId != null;

  bool get isStep3Complete => images.isNotEmpty;

  bool get isReadyToPublish => isStep1Complete && isStep2Complete && isStep3Complete;

  String get title => [brandName, modelName, variant].where((s) => s != null && s.isNotEmpty).join(' ');

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
    List<XFile>? images,
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
      images: images ?? this.images,
    );
  }
}
