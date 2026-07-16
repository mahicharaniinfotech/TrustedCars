class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.imageUrl,
    this.readAt,
    required this.createdAt,
  });

  final int id;
  final int conversationId;
  final String senderId;
  final String body;
  final String? imageUrl;
  final DateTime? readAt;
  final DateTime createdAt;

  bool isMine(String currentAccountId) => senderId == currentAccountId;

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as int,
      conversationId: map['conversation_id'] as int,
      senderId: map['sender_id'] as String,
      body: map['body'] as String,
      imageUrl: map['image_url'] as String?,
      readAt: map['read_at'] == null ? null : DateTime.parse(map['read_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// A conversation as shown in the conversation list -- pre-joined with
/// the vehicle's display info and the other participant's name, so the
/// list screen doesn't need N+1 queries per row.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.vehicleId,
    required this.vehicleTitle,
    this.vehicleImageUrl,
    required this.otherPartyName,
    required this.isBuyer,
    required this.lastMessageAt,
  });

  final int id;
  final int vehicleId;
  final String vehicleTitle;
  final String? vehicleImageUrl;
  final String otherPartyName;
  final bool isBuyer;
  final DateTime lastMessageAt;
}
