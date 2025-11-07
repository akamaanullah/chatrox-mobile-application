class ChatMessage {
  final int id;
  final int senderId;
  final String userName;
  final String userAvatar;
  final String content;
  final String time;
  final String dateKey;
  final bool hasMedia;
  final bool hasVoice;
  final int? replyToId;
  final bool isForwarded;
  final bool isEdited;
  final bool isDeleted;
  final bool isPinned;
  final List<dynamic> mediaFiles;
  final String? voiceFile;
  final int? voiceDuration;
  final List<dynamic> reactions;
  final Map<String, dynamic>? replyTo;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.time,
    required this.dateKey,
    required this.hasMedia,
    required this.hasVoice,
    this.replyToId,
    required this.isForwarded,
    required this.isEdited,
    required this.isDeleted,
    required this.isPinned,
    required this.mediaFiles,
    this.voiceFile,
    this.voiceDuration,
    required this.reactions,
    this.replyTo,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Try to resolve content from multiple possible keys
    String content = '';
    if (json['content'] != null && json['content'].toString().trim().isNotEmpty) {
      content = json['content'];
    } else if (json['text'] != null && json['text'].toString().trim().isNotEmpty) {
      content = json['text'];
    } else if (json['message'] != null && json['message'].toString().trim().isNotEmpty) {
      content = json['message'];
    }
    return ChatMessage(
      id: json['id'],
      senderId: json['sender_id'],
      userName: json['user_name'] ?? '',
      userAvatar: json['user_avatar'] ?? '',
      content: content,
      time: json['time'] ?? '',
      dateKey: json['date_key'] ?? '',
      hasMedia: json['has_media'] == 1,
      hasVoice: json['has_voice'] == 1,
      replyToId: json['reply_to_id'],
      isForwarded: json['is_forwarded'] == 1,
      isEdited: json['is_edited'] == 1,
      isDeleted: json['is_deleted'] == 1,
      isPinned: json['is_pinned'] == 1,
      mediaFiles: List<Map<String, dynamic>>.from(json['media_files'] ?? []),
      voiceFile: json['voice_file'],
      voiceDuration: json['voice_duration'],
      reactions: List<Map<String, dynamic>>.from(json['reactions'] ?? []),
      replyTo:
          json['reply_to'] != null
              ? Map<String, dynamic>.from(json['reply_to'])
              : null,
    );
  }
}
