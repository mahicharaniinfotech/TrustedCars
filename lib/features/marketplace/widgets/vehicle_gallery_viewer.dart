import 'package:flutter/material.dart';

import '../models/photo_requirement.dart';

/// A single labeled photo in the buyer-facing gallery.
class GalleryPhoto {
  final String url;
  final String label;
  final PhotoCategory category;

  const GalleryPhoto({
    required this.url,
    required this.label,
    required this.category,
  });
}

/// Category-tabbed, swipeable gallery for the vehicle detail screen —
/// mirrors the reference pattern: circular category avatars up top,
/// full-bleed photos with a bottom-left label chip, swipe between shots,
/// tapping a category jumps to its first photo.
///
/// Feed this widget the vehicle's listing_photos (joined with
/// photo_requirements.category/label, or feature_tags.label for Features
/// category) sorted the way you want them to appear.
class VehicleGalleryViewer extends StatefulWidget {
  final List<GalleryPhoto> photos;
  final List<PhotoCategory> categoryOrder;

  const VehicleGalleryViewer({
    super.key,
    required this.photos,
    this.categoryOrder = const [
      PhotoCategory.exterior,
      PhotoCategory.interior,
      PhotoCategory.features,
      PhotoCategory.highlights,
      PhotoCategory.tyres,
    ],
  });

  @override
  State<VehicleGalleryViewer> createState() => _VehicleGalleryViewerState();
}

class _VehicleGalleryViewerState extends State<VehicleGalleryViewer> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  PhotoCategory get _activeCategory =>
      widget.photos.isEmpty ? PhotoCategory.exterior : widget.photos[_currentIndex].category;

  void _jumpToCategory(PhotoCategory cat) {
    final index = widget.photos.indexWhere((p) => p.category == cat);
    if (index == -1) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: Container(
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.directions_car, size: 48)),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: widget.photos.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, i) {
                  final photo = widget.photos[i];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(photo.url, fit: BoxFit.cover),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            photo.label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${widget.photos.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: widget.categoryOrder.map((cat) {
                final isActive = cat == _activeCategory;
                final thumb = widget.photos
                    .firstWhere((p) => p.category == cat, orElse: () => widget.photos.first);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => _jumpToCategory(cat),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade800,
                          backgroundImage: NetworkImage(thumb.url),
                          child: isActive
                              ? Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cat.label,
                          style: TextStyle(
                            color: isActive
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
