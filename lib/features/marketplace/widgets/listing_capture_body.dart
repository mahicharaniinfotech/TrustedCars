import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/photo_requirement.dart';
import '../models/feature_tag.dart';
import '../providers/listing_capture_provider.dart';

/// The reusable capture surface: progress bar, category tabs, slot grid,
/// and feature checklist. Assumes the parent has already called (or is in
/// the process of calling) `listingCaptureProvider.notifier.loadVehicle()`.
///
/// Used by both `ListingChecklistScreen` (standalone, e.g. editing photos
/// on an existing listing) and `_PhotosStep` in the Sell Vehicle flow
/// (embedded, with its own Back/Next footer instead of a publish button).
class ListingCaptureBody extends ConsumerStatefulWidget {
  const ListingCaptureBody({super.key});

  @override
  ConsumerState<ListingCaptureBody> createState() =>
      _ListingCaptureBodyState();
}

class _ListingCaptureBodyState extends ConsumerState<ListingCaptureBody> {
  PhotoCategory _activeCategory = PhotoCategory.exterior;
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final captureAsync = ref.watch(listingCaptureProvider);

    return captureAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Something went wrong: $e')),
      data: (state) => Column(
        children: [
          _buildProgressBar(state),
          _buildCategoryTabs(state),
          Expanded(child: _buildCategoryBody(state)),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ListingCaptureState state) {
    final total = state.totalMandatoryCount;
    final done = total - state.remainingMandatoryCount;
    final progress = total == 0 ? 1.0 : done / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.remainingMandatoryCount == 0
                ? 'All required photos added'
                : '${state.remainingMandatoryCount} required photo(s) remaining',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(ListingCaptureState state) {
    final categories = [
      PhotoCategory.exterior,
      PhotoCategory.interior,
      PhotoCategory.features,
      PhotoCategory.tyres,
    ];

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: categories.map((cat) {
          final isActive = cat == _activeCategory;
          final incomplete = _categoryIncompleteCount(state, cat);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () => setState(() => _activeCategory = cat),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade200,
                        child: Icon(
                          _iconFor(cat),
                          color: isActive ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                      if (incomplete > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$incomplete',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade600,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  int _categoryIncompleteCount(ListingCaptureState state, PhotoCategory cat) {
    if (cat == PhotoCategory.features) {
      return state.selectedFeatures
          .where((k) => !state.featurePhotos.containsKey(k))
          .length;
    }
    return state
        .requirementsFor(cat)
        .where((r) =>
            r.isMandatoryFor(state.accountType) &&
            !state.slotPhotos.containsKey(r.id))
        .length;
  }

  IconData _iconFor(PhotoCategory cat) => switch (cat) {
        PhotoCategory.exterior => Icons.directions_car_outlined,
        PhotoCategory.interior => Icons.dashboard_customize_outlined,
        PhotoCategory.tyres => Icons.tire_repair_outlined,
        PhotoCategory.features => Icons.star_outline,
        PhotoCategory.highlights => Icons.auto_awesome_outlined,
      };

  Widget _buildCategoryBody(ListingCaptureState state) {
    if (_activeCategory == PhotoCategory.features) {
      return _buildFeaturesList(state);
    }
    return _buildSlotGrid(state);
  }

  Widget _buildSlotGrid(ListingCaptureState state) {
    final requirements = state.requirementsFor(_activeCategory);
    if (requirements.isEmpty) {
      return const Center(child: Text('No shots configured for this category'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: requirements.length,
      itemBuilder: (context, i) {
        final req = requirements[i];
        final mandatory = req.isMandatoryFor(state.accountType);
        final photoUrl = state.slotPhotos[req.id];
        return _SlotCard(
          label: req.label,
          mandatory: mandatory,
          photoUrl: photoUrl,
          onTap: () => _captureSlot(req),
        );
      },
    );
  }

  Widget _buildFeaturesList(ListingCaptureState state) {
    final grouped = <String, List<FeatureTag>>{};
    for (final tag in state.featureTags) {
      grouped.putIfAbsent(tag.groupName, () => []).add(tag);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key[0].toUpperCase() + entry.key.substring(1),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...entry.value.map((tag) {
              final selected = state.selectedFeatures.contains(tag.key);
              final hasPhoto = state.featurePhotos.containsKey(tag.key);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(tag.label),
                          value: selected,
                          onChanged: (v) => ref
                              .read(listingCaptureProvider.notifier)
                              .toggleFeature(tag.key, v ?? false),
                        ),
                      ),
                      if (selected)
                        IconButton(
                          icon: Icon(
                            hasPhoto
                                ? Icons.check_circle
                                : Icons.camera_alt_outlined,
                            color: hasPhoto ? Colors.green : Colors.grey,
                          ),
                          onPressed: () => _captureFeature(tag.key),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      }).toList(),
    );
  }

  Future<void> _captureSlot(PhotoRequirement req) async {
    final file =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      await ref.read(listingCaptureProvider.notifier).uploadPhoto(
            requirement: req,
            bytes: Uint8List.fromList(bytes),
            fileExtension: file.name.split('.').last,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _captureFeature(String featureKey) async {
    final file =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      await ref.read(listingCaptureProvider.notifier).uploadPhoto(
            featureKey: featureKey,
            bytes: Uint8List.fromList(bytes),
            fileExtension: file.name.split('.').last,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }
}

class _SlotCard extends StatelessWidget {
  final String label;
  final bool mandatory;
  final String? photoUrl;
  final VoidCallback onTap;

  const _SlotCard({
    required this.label,
    required this.mandatory,
    required this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final filled = photoUrl != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade100,
          border: Border.all(
            color: filled
                ? Colors.green
                : (mandatory ? Colors.orange.shade300 : Colors.grey.shade300),
            width: filled ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (filled)
              ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.network(photoUrl!, fit: BoxFit.cover),
              )
            else
              Center(
                child: Icon(Icons.camera_alt_outlined,
                    color: Colors.grey.shade400, size: 32),
              ),
            Positioned(
              left: 6,
              bottom: 6,
              right: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (filled)
              const Positioned(
                right: 6,
                top: 6,
                child: Icon(Icons.check_circle, color: Colors.green, size: 20),
              )
            else if (mandatory)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Required',
                      style: TextStyle(color: Colors.white, fontSize: 9)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
