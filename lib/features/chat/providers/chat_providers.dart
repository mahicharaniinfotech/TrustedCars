import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/chat_models.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository());

final conversationsProvider = FutureProvider<List<ConversationSummary>>((ref) async {
  final account = await ref.watch(currentAccountProvider.future);
  if (account == null) return [];
  return ref.watch(chatRepositoryProvider).getConversations(account.id);
});

/// Live message stream for a single conversation.
final messagesStreamProvider =
    StreamProvider.family<List<ChatMessage>, int>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).streamMessages(conversationId);
});
