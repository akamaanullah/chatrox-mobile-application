import 'package:html/parser.dart' show parse;
import '../config/api_config.dart';

class RecentMessage {
  final int id;
  final int userId;
  final int conversationId;
  final String conversationType;
  final int lastMessageId;
  final String? content;
  final DateTime updatedAt;
  final DateTime createdAt;
  
  // Private message fields
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? profilePicture;
  
  // Channel message fields
  final String? channelName;
  final String? channelAvatar;
  
  // Media and voice fields
  final List<Map<String, dynamic>>? mediaFiles;
  final String? voiceFile;
  final int? voiceDuration;
  final int? unreadCount;

  RecentMessage({
    required this.id,
    required this.userId,
    required this.conversationId,
    required this.conversationType,
    required this.lastMessageId,
    this.content,
    required this.updatedAt,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.username,
    this.profilePicture,
    this.channelName,
    this.channelAvatar,
    this.mediaFiles,
    this.voiceFile,
    this.voiceDuration,
    this.unreadCount,
  });

  factory RecentMessage.fromJson(Map<String, dynamic> json) {
    String? profilePic = json['profile_picture'];
    if (profilePic != null && profilePic.isNotEmpty && !profilePic.startsWith('http')) {
      // Ensure only one slash at the start
      if (!profilePic.startsWith('/')) {
        profilePic = '/$profilePic';
      }
      profilePic = ApiConfig.getAssetUrl(profilePic);
    }
    String? channelAvatar = json['channel_avatar'];
    if (channelAvatar != null && channelAvatar.isNotEmpty && !channelAvatar.startsWith('http')) {
      channelAvatar = ApiConfig.getAssetUrl(channelAvatar);
    }
    return RecentMessage(
      id: int.parse(json['id'].toString()),
      userId: json['user_id'] != null ? int.tryParse(json['user_id'].toString()) ?? 0 : 0,
      conversationId: int.parse(json['conversation_id'].toString()),
      conversationType: json['conversation_type'],
      lastMessageId: int.parse(json['last_message_id'].toString()),
      content: json['content'],
      updatedAt: DateTime.parse(json['updated_at']),
      createdAt: DateTime.now(),
      firstName: json['first_name'],
      lastName: json['last_name'],
      username: json['username'],
      profilePicture: profilePic,
      channelName: json['channel_name'],
      channelAvatar: channelAvatar,
      mediaFiles: json['media_files'] != null
          ? List<Map<String, dynamic>>.from(json['media_files'])
          : [],
      voiceFile: json['voice_file'],
      voiceDuration: json['voice_duration'] != null ? int.tryParse(json['voice_duration'].toString()) : null,
      unreadCount: json['unread_count'] != null ? int.tryParse(json['unread_count'].toString()) : 0,
    );
  }

  String get displayName {
    if (conversationType == 'private') {
      if ((firstName != null && firstName!.isNotEmpty) || (lastName != null && lastName!.isNotEmpty)) {
        return '${firstName ?? ''} ${lastName ?? ''}'.trim();
      }
      return username ?? 'Unknown User';
    } else {
      return channelName ?? 'Unknown Channel';
    }
  }

  String get avatarUrl {
    if (conversationType == 'private') {
      return profilePicture ?? '';
    } else {
      return channelAvatar ?? '';
    }
  }

  String get lastMessagePreview {
    if (voiceFile != null) {
      return '🎤 Voice message';
    } else if (mediaFiles != null && mediaFiles!.isNotEmpty) {
      return '�� Media';
    } else if (content != null) {
      // Remove HTML tags and decode HTML entities
      final document = parse(content!);
      String plainText = document.body?.text ?? '';
      
      // Trim extra spaces and newlines
      plainText = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Return empty string if plain text is empty or just whitespace
      return plainText.isEmpty ? '' : plainText;
    }
    return '';
  }
} 