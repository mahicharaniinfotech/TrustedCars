import '../../../core/config/supabase_config.dart';
import '../models/chat_models.dart';

/// Reads and writes conversations/messages (migration 009). Deliberately
/// avoids PostgREST embedded joins across the public_profiles view or
/// multi-hop relationships (same lesson learned in the vehicle detail
/// screen) -- batches simple `.filter('id', 'in', ...)` lookups instead,
/// which is slightly more code but doesn't depend on PostgREST correctly
/// inferring a relationship that may not be embeddable at all.
class ChatRepository {
  /// One conversation per (vehicle, buyer) pair. Returns the existing
  /// conversation id if the buyer already messaged about this vehicle,
  /// otherwise creates a new one.
  Future<int> getOrCreateConversation({
    required int vehicleId,
    required String buyerId,
    required String sellerId,
  }) async {
    final existing = await supabase
        .from('conversations')
        .select('id')
        .eq('vehicle_id', vehicleId)
        .eq('buyer_id', buyerId)
        .maybeSingle();
    if (existing != null) return existing['id'] as int;

    final created = await supabase
        .from('conversations')
        .insert({'vehicle_id': vehicleId, 'buyer_id': buyerId, 'seller_id': sellerId})
        .select('id')
        .single();
    return created['id'] as int;
  }

  Future<List<ConversationSummary>> getConversations(String accountId) async {
    final rows = await supabase
        .from('conversations')
        .select('id, vehicle_id, buyer_id, seller_id, last_message_at')
        .or('buyer_id.eq.$accountId,seller_id.eq.$accountId')
        .order('last_message_at', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return [];

    final vehicleIds = list.map((r) => r['vehicle_id'] as int).toSet().toList();
    final otherPartyIds = list.map((r) {
      final buyerId = r['buyer_id'] as String;
      final sellerId = r['seller_id'] as String;
      return buyerId == accountId ? sellerId : buyerId;
    }).toSet().toList();

    final vehicleRows = await supabase
        .from('vehicles')
        .select('id, variant, brands(name), vehicle_models(name), vehicle_images(image_url, is_primary)')
        .filter('id', 'in', '(${vehicleIds.join(",")})');
    final vehiclesById = {
      for (final v in (vehicleRows as List)) v['id'] as int: v as Map<String, dynamic>,
    };

    final profileRows = await supabase
        .from('public_profiles')
        .select('id, full_name')
        .filter('id', 'in', '(${otherPartyIds.map((id) => '"$id"').join(",")})');
    final namesById = {
      for (final p in (profileRows as List)) p['id'] as String: p['full_name'] as String?,
    };

    return list.map((r) {
      final buyerId = r['buyer_id'] as String;
      final sellerId = r['seller_id'] as String;
      final otherId = buyerId == accountId ? sellerId : buyerId;
      final vehicle = vehiclesById[r['vehicle_id'] as int];
      final brand = vehicle?['brands'] as Map<String, dynamic>?;
      final model = vehicle?['vehicle_models'] as Map<String, dynamic>?;
      final images = (vehicle?['vehicle_images'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final primaryImage =
          images.isEmpty ? null : images.firstWhere((i) => i['is_primary'] == true, orElse: () => images.first);

      final title = [brand?['name'], model?['name'], vehicle?['variant']]
          .where((s) => s != null && (s as String).isNotEmpty)
          .join(' ');

      return ConversationSummary(
        id: r['id'] as int,
        vehicleId: r['vehicle_id'] as int,
        vehicleTitle: title.isEmpty ? 'Vehicle' : title,
        vehicleImageUrl: primaryImage?['image_url'] as String?,
        otherPartyName: namesById[otherId] ?? 'User',
        isBuyer: buyerId == accountId,
        lastMessageAt: DateTime.parse(r['last_message_at'] as String),
      );
    }).toList();
  }

  Future<List<ChatMessage>> getMessages(int conversationId) async {
    final rows = await supabase
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return (rows as List).map((r) => ChatMessage.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Live stream of messages in a conversation via Supabase Realtime
  /// (enabled for the `messages` table in migration 009).
  Stream<List<ChatMessage>> streamMessages(int conversationId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows.map((r) => ChatMessage.fromMap(r)).toList());
  }

  Future<void> sendMessage({
    required int conversationId,
    required String senderId,
    required String body,
  }) async {
    await supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': senderId,
      'body': body,
    });
  }

  Future<void> markAsRead(int conversationId, String accountId) async {
    await supabase
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', accountId)
        .filter('read_at', 'is', null);
  }
}
