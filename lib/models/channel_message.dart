import 'dart:convert';

class ChannelMessage {
  final int id;
  final int senderId;
  final String content;
  final String createdAt;
  final String userName;
  final String? userAvatar;
  final bool isEdited;
  final bool isDeleted;
  final bool isForwarded;
  final bool isPinned;
  final bool hasMedia;
  final List<MediaFile> mediaFiles;
  final bool hasVoice;
  final ReplyTo? replyTo;
  final List<Reaction> reactions;
  final String time;

  ChannelMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    required this.userName,
    this.userAvatar,
    required this.isEdited,
    required this.isDeleted,
    required this.isForwarded,
    required this.isPinned,
    required this.hasMedia,
    required this.mediaFiles,
    required this.hasVoice,
    this.replyTo,
    required this.reactions,
    required this.time,
  });

  factory ChannelMessage.fromJson(Map<String, dynamic> json) {
    return ChannelMessage(
      id: json['id'],
      senderId: json['sender_id'],
      content: json['content'],
      createdAt: json['created_at'],
      userName: json['user_name'],
      userAvatar: json['user_avatar'],
      isEdited: json['is_edited'] == 1,
      isDeleted: json['is_deleted'] == 1,
      isForwarded: json['is_forwarded'] == 1,
      isPinned: json['is_pinned'] == 1,
      hasMedia: json['has_media'] == 1,
      mediaFiles: (json['media_files'] as List?)
          ?.map((file) => MediaFile.fromJson(file))
          .toList() ?? [],
      hasVoice: json['has_voice'] == 1,
      replyTo: json['reply_to'] != null ? ReplyTo.fromJson(json['reply_to']) : null,
      reactions: (json['reactions'] as List?)
          ?.map((reaction) => Reaction.fromJson(reaction))
          .toList() ?? [],
      time: json['time'],
    );
  }
}

class MediaFile {
  final String filePath;
  final String fileType;
  final String mediaName;
  final String uploadedAt;

  MediaFile({
    required this.filePath,
    required this.fileType,
    required this.mediaName,
    required this.uploadedAt,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      filePath: json['file_path'],
      fileType: json['file_type'],
      mediaName: json['media_name'],
      uploadedAt: json['uploaded_at'],
    );
  }
}

class ReplyTo {
  final String userName;
  final String content;
  final bool hasMedia;
  final List<MediaFile> mediaFiles;

  ReplyTo({
    required this.userName,
    required this.content,
    required this.hasMedia,
    required this.mediaFiles,
  });

  factory ReplyTo.fromJson(Map<String, dynamic> json) {
    return ReplyTo(
      userName: json['user_name'],
      content: json['content'],
      hasMedia: json['has_media'] == true || json['has_media'] == 1,
      mediaFiles: (json['media_files'] as List?)
          ?.map((file) => MediaFile.fromJson(file))
          .toList() ?? [],
    );
  }
}

class Reaction {
  final String emoji;
  final int count;
  final String users;
  final bool isReacted;

  Reaction({
    required this.emoji,
    required this.count,
    required this.users,
    required this.isReacted,
  });

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      emoji: json['emoji'],
      count: json['count'],
      users: json['users'],
      isReacted: json['is_reacted'] == true || json['is_reacted'] == 1,
    );
  }
} 