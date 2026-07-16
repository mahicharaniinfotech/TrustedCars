enum FuelType { petrol, diesel, cng, electric, hybrid }

enum TransmissionType { manual, automatic }

enum VehicleStatus { draft, published, sold, removed }

enum VehicleCategory { car, bike, commercial }

T _enumFromString<T>(List<T> values, String? value, T fallback) {
  return values.firstWhere(
    (e) => e.toString().split('.').last == value,
    orElse: () => fallback,
  );
}

/// Mirrors a row in the `vehicles` table, joined with brand/model/city
/// names and a primary image where available (see VehicleRepository's
/// select string for the exact joined shape).
class Vehicle {
  const Vehicle({
    required this.id,
    required this.accountId,
    required this.category,
    required this.year,
    required this.fuelType,
    required this.transmission,
    required this.kmDriven,
    required this.price,
    required this.status,
    required this.isFeatured,
    this.brandName,
    this.modelName,
    this.variant,
    this.description,
    this.cityName,
    this.primaryImageUrl,
  });

  final int id;
  final String accountId;
  final VehicleCategory category;
  final int year;
  final FuelType fuelType;
  final TransmissionType transmission;
  final int kmDriven;
  final double price;
  final VehicleStatus status;
  final bool isFeatured;
  final String? brandName;
  final String? modelName;
  final String? variant;
  final String? description;
  final String? cityName;
  final String? primaryImageUrl;

  String get title => [brandName, modelName, variant].where((s) => s != null && s.isNotEmpty).join(' ');

  String get formattedPrice {
    if (price >= 10000000) return '₹${(price / 10000000).toStringAsFixed(2)} Cr';
    if (price >= 100000) return '₹${(price / 100000).toStringAsFixed(2)} Lakh';
    return '₹${price.toStringAsFixed(0)}';
  }

  String get formattedKm {
    if (kmDriven >= 100000) return '${(kmDriven / 100000).toStringAsFixed(1)}L km';
    if (kmDriven >= 1000) return '${(kmDriven / 1000).toStringAsFixed(0)}K km';
    return '$kmDriven km';
  }

  String get fuelLabel => fuelType.name[0].toUpperCase() + fuelType.name.substring(1);

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    final brand = map['brands'] as Map<String, dynamic>?;
    final model = map['vehicle_models'] as Map<String, dynamic>?;
    final city = map['cities'] as Map<String, dynamic>?;
    final images = map['vehicle_images'] as List<dynamic>?;
    final primaryImage = (images != null && images.isNotEmpty)
        ? images.cast<Map<String, dynamic>>().firstWhere(
              (img) => img['is_primary'] == true,
              orElse: () => images.first as Map<String, dynamic>,
            )
        : null;

    return Vehicle(
      id: map['id'] as int,
      accountId: map['account_id'] as String,
      category: _enumFromString(VehicleCategory.values, map['category'] as String?, VehicleCategory.car),
      year: map['year'] as int,
      fuelType: _enumFromString(FuelType.values, map['fuel_type'] as String?, FuelType.petrol),
      transmission: _enumFromString(TransmissionType.values, map['transmission'] as String?, TransmissionType.manual),
      kmDriven: map['km_driven'] as int? ?? 0,
      price: (map['price'] as num).toDouble(),
      status: _enumFromString(VehicleStatus.values, map['status'] as String?, VehicleStatus.draft),
      isFeatured: map['is_featured'] as bool? ?? false,
      brandName: brand?['name'] as String?,
      modelName: model?['name'] as String?,
      variant: map['variant'] as String?,
      description: map['description'] as String?,
      cityName: city?['name'] as String?,
      primaryImageUrl: primaryImage?['image_url'] as String?,
    );
  }
}
