import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/supabase_config.dart';
import '../../marketplace/models/vehicle.dart';

class BrandOption {
  const BrandOption({required this.id, required this.name});
  final int id;
  final String name;
}

class CityOption {
  const CityOption({required this.id, required this.name});
  final int id;
  final String name;
}

/// Brands for the filter sheet's dropdown, scoped to whichever category
/// is currently selected (cars vs bikes have entirely different brand lists).
final brandsForCategoryProvider =
    FutureProvider.family<List<BrandOption>, VehicleCategory>((ref, category) async {
  final rows = await supabase
      .from('brands')
      .select('id, name')
      .eq('category', category.name)
      .order('name');
  return (rows as List)
      .map((r) => BrandOption(id: r['id'] as int, name: r['name'] as String))
      .toList();
});

/// All cities for the filter sheet's location dropdown. Small enough
/// dataset (dozens, not thousands) to just load in full rather than
/// paginate or search-as-you-type.
final citiesProvider = FutureProvider<List<CityOption>>((ref) async {
  final rows = await supabase.from('cities').select('id, name').order('name');
  return (rows as List)
      .map((r) => CityOption(id: r['id'] as int, name: r['name'] as String))
      .toList();
});

/// Models for a specific brand -- used by Sell Vehicle's dependent
/// brand -> model dropdown (Sprint 5).
final modelsForBrandProvider = FutureProvider.family<List<BrandOption>, int>((ref, brandId) async {
  final rows = await supabase
      .from('vehicle_models')
      .select('id, name')
      .eq('brand_id', brandId)
      .order('name');
  return (rows as List)
      .map((r) => BrandOption(id: r['id'] as int, name: r['name'] as String))
      .toList();
});
