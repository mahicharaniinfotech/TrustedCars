import '../../marketplace/models/vehicle.dart';

enum SortOption { newest, priceLowHigh, priceHighLow, kmLowHigh }

/// Immutable search criteria. Passed as-is into VehicleRepository.searchVehicles.
class VehicleFilter {
  const VehicleFilter({
    this.searchQuery,
    this.category = VehicleCategory.car,
    this.brandId,
    this.minPrice,
    this.maxPrice,
    this.fuelType,
    this.transmission,
    this.minYear,
    this.maxYear,
    this.cityId,
  });

  final String? searchQuery;
  final VehicleCategory category;
  final int? brandId;
  final double? minPrice;
  final double? maxPrice;
  final FuelType? fuelType;
  final TransmissionType? transmission;
  final int? minYear;
  final int? maxYear;
  final int? cityId;

  bool get hasActiveFilters =>
      brandId != null ||
      minPrice != null ||
      maxPrice != null ||
      fuelType != null ||
      transmission != null ||
      minYear != null ||
      maxYear != null ||
      cityId != null;

  int get activeFilterCount => [
        brandId,
        minPrice,
        maxPrice,
        fuelType,
        transmission,
        minYear,
        maxYear,
        cityId,
      ].where((v) => v != null).length;

  VehicleFilter copyWith({
    String? searchQuery,
    bool clearSearchQuery = false,
    VehicleCategory? category,
    int? brandId,
    bool clearBrandId = false,
    double? minPrice,
    bool clearMinPrice = false,
    double? maxPrice,
    bool clearMaxPrice = false,
    FuelType? fuelType,
    bool clearFuelType = false,
    TransmissionType? transmission,
    bool clearTransmission = false,
    int? minYear,
    bool clearMinYear = false,
    int? maxYear,
    bool clearMaxYear = false,
    int? cityId,
    bool clearCityId = false,
  }) {
    return VehicleFilter(
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      category: category ?? this.category,
      brandId: clearBrandId ? null : (brandId ?? this.brandId),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      fuelType: clearFuelType ? null : (fuelType ?? this.fuelType),
      transmission: clearTransmission ? null : (transmission ?? this.transmission),
      minYear: clearMinYear ? null : (minYear ?? this.minYear),
      maxYear: clearMaxYear ? null : (maxYear ?? this.maxYear),
      cityId: clearCityId ? null : (cityId ?? this.cityId),
    );
  }

  VehicleFilter clearAllFilters() => VehicleFilter(searchQuery: searchQuery, category: category);
}
