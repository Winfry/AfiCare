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
          ? DateTime.parse(json['read_at'] as String).toLocal()
          : null,
      // Stored in UTC; shown in the phone's own time.
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
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

/// Someone the patient may start a conversation with, from
/// `message_contacts()` (migration 049): a clinician caring for her or
/// one of her dependants, or someone who has written to her.
class MessageContact {
  final String id;
  final String name;
  final String? role;
  final String? photoUrl;
  final String? gender;

  /// Ids of the people (her, her dependants) this clinician looks after.
  final List<String> caresFor;
  final List<String> caresForNames;

  const MessageContact({
    required this.id,
    required this.name,
    this.role,
    this.photoUrl,
    this.gender,
    this.caresFor = const [],
    this.caresForNames = const [],
  });

  factory MessageContact.fromJson(Map<String, dynamic> json) {
    final name = (json['full_name'] as String?)?.trim() ?? '';
    return MessageContact(
      id: json['user_id'] as String,
      name: name.isEmpty ? 'Your clinician' : name,
      role: json['role'] as String?,
      photoUrl: json['photo_url'] as String?,
      gender: json['gender'] as String?,
      caresFor: [for (final v in (json['cares_for'] as List?) ?? const []) '$v'],
      caresForNames: [for (final v in (json['cares_for_names'] as List?) ?? const []) '$v'],
    );
  }

  /// "Doctor", "Nurse"…
  String get roleLabel => switch (role) {
        'doctor' => 'Doctor',
        'nurse' => 'Nurse',
        'chw' => 'Community health worker',
        'radiologist' => 'Radiologist',
        'facility_admin' => 'Facility staff',
        null || '' => 'Clinician',
        _ => '${role![0].toUpperCase()}${role!.substring(1)}',
      };
}
