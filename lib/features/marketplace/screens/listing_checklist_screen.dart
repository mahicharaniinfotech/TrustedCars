import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ASSUMPTION: matches the convention seen in sell_repository.dart —
// a top-level `supabase` client exported from this config file. Adjust the
// import path if your project structure differs.
import '../../../core/config/supabase_config.dart';

import '../providers/listing_capture_provider.dart';
import '../widgets/listing_capture_body.dart';

/// Standalone entry point for the structured photo checklist — e.g.
/// "Edit photos" on an already-published listing. The Sell Vehicle flow
/// does NOT use this screen directly; it embeds ListingCaptureBody as its
/// own Photos step instead (see sell_photos_step.dart), since that step
/// needs Back/Next buttons rather than a standalone publish action.
class ListingChecklistScreen extends ConsumerStatefulWidget {
  final int vehicleId;

  const ListingChecklistScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<ListingChecklistScreen> createState() =>
      _ListingChecklistScreenState();
}

class _ListingChecklistScreenState
    extends ConsumerState<ListingChecklistScreen> {
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    ref.read(listingCaptureProvider.notifier).loadVehicle(widget.vehicleId);
  }

  @override
  Widget build(BuildContext context) {
    final captureAsync = ref.watch(listingCaptureProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle photos')),
      body: const ListingCaptureBody(),
      bottomNavigationBar: captureAsync.maybeWhen(
        data: (state) => _buildPublishBar(state),
        orElse: () => null,
      ),
    );
  }

  Widget _buildPublishBar(ListingCaptureState state) {
    final ready = state.remainingMandatoryCount == 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: (ready && !_isPublishing) ? _handlePublish : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
          child: _isPublishing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(ready
                  ? 'Publish listing'
                  : '${state.remainingMandatoryCount} photo(s) remaining'),
        ),
      ),
    );
  }

  Future<void> _handlePublish() async {
    setState(() => _isPublishing = true);
    final notifier = ref.read(listingCaptureProvider.notifier);
    try {
      final result = await notifier.checkCompleteness();
      if (!result.complete) {
        if (mounted) _showMissingSheet(result.missingLabels);
        return;
      }
      await supabase
          .from('vehicles')
          .update({'status': 'published'}).eq('id', widget.vehicleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing published!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Publish failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _showMissingSheet(List<String> missing) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${missing.length} item(s) still needed',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...missing.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6),
                      const SizedBox(width: 8),
                      Text(m),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
