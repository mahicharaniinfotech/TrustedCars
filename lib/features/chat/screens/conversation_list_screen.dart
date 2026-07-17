import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimensions.dart';
import '../models/chat_models.dart';
import '../providers/chat_providers.dart';

class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: conversationsAsync.when(
        data: (conversations) => conversations.isEmpty
            ? Center(
                child: Text('No conversations yet', style: theme.textTheme.bodyMedium),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(conversationsProvider),
                child: ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ConversationTile(conversation: conversations[i]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load messages: $e')),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation});

  final ConversationSummary conversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      leading: ClipRRect(
        borderRadius: AppRadius.smAll,
        child: SizedBox(
          width: 56,
          height: 56,
          child: conversation.vehicleImageUrl != null
              ? Image.network(conversation.vehicleImageUrl!, fit: BoxFit.cover)
              : Container(
                  color: theme.colorScheme.surface,
                  child: Icon(Icons.directions_car_outlined, color: theme.colorScheme.outline),
                ),
        ),
      ),
      title: Text(conversation.otherPartyName, style: theme.textTheme.titleLarge),
      subtitle: Text(
        conversation.vehicleTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(_relativeTime(conversation.lastMessageAt), style: theme.textTheme.bodySmall),
      onTap: () => context.push(
        '/chat/${conversation.id}',
        extra: {'otherPartyName': conversation.otherPartyName, 'vehicleTitle': conversation.vehicleTitle},
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}
