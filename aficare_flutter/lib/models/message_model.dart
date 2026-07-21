enum MessageType { text, image, labResult, referral, appointment }

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String? patientId;
  final String content;
  final MessageType messageType;
  final String? referenceId;
  final bool read;
  final DateTime? readAt;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.patientId,
    required this.content,
    this.messageType = MessageType.text,
    this.referenceId,
    this.read = false,
    this.readAt,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      patientId: json['patient_id'] as String?,
      content: json['content'] as String,
      messageType: _typeFromString(json['message_type'] as String? ?? 'text'),
      referenceId: json['reference_id'] as String?,
      read: (json['read'] as bool?) ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'patient_id': patientId,
      'content': content,
      'message_type': _typeToString(messageType),
      'reference_id': referenceId,
      'read': read,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  static MessageType _typeFromString(String s) {
    switch (s) {
      case 'image':
        return MessageType.image;
      case 'lab_result':
        return MessageType.labResult;
      case 'referral':
        return MessageType.referral;
      case 'appointment':
        return MessageType.appointment;
      default:
        return MessageType.text;
    }
  }

  static String _typeToString(MessageType t) {
    switch (t) {
      case MessageType.image:
        return 'image';
      case MessageType.labResult:
        return 'lab_result';
      case MessageType.referral:
        return 'referral';
      case MessageType.appointment:
        return 'appointment';
      case MessageType.text:
        return 'text';
    }
  }
}

/// A lightweight conversation summary derived from the latest message
/// exchanged with a given counterpart user.
class ConversationSummary {
  final String counterpartId;
  final String counterpartName;
  final String? counterpartRole;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  ConversationSummary({
    required this.counterpartId,
    required this.counterpartName,
    this.counterpartRole,
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
  });
}
