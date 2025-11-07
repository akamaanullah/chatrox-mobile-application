import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/channel_message.dart';
import '../utils/storage.dart';

class ChannelMessageService {
  static const String baseUrl = 'http://172.16.32.59:8886/chatrox-api';

  static Future<Map<String, List<ChannelMessage>>> getChannelMessages({
    required int channelId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = await Storage.getUserId();
      final token = await Storage.getToken();
      final url = Uri.parse(
        '$baseUrl/messages/get_channel_messages.php?channel_id=$channelId&user_id=$userId&limit=$limit&offset=$offset'
      );
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final raw = data['data'];
          if (raw is List) {
            // List hai, to ek default group bana lo
            return {
              "Messages": (raw as List).map((m) => ChannelMessage.fromJson(m)).toList(),
            };
          } else if (raw is Map<String, dynamic>) {
            // Grouped hai
            return raw.map((date, msgs) => MapEntry(
              date,
              (msgs as List).map((m) => ChannelMessage.fromJson(m)).toList(),
            ));
          } else {
            return {};
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to load messages');
        }
      } else {
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading messages: $e');
    }
  }

  static Future<void> sendChannelMessage({
    required int channelId,
    required String content,
    List<String>? mediaFiles,
    String? replyToMessageId,
  }) async {
    try {
      final userId = await Storage.getUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/messages/send_channel_message.php'),
        body: {
          'channel_id': channelId.toString(),
          'user_id': userId.toString(),
          'content': content,
          if (mediaFiles != null) 'media_files': json.encode(mediaFiles),
          if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to send message: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  static Future<void> deleteChannelMessage({
    required int messageId,
    required int channelId,
  }) async {
    try {
      final userId = await Storage.getUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/messages/delete_channel_message.php'),
        body: {
          'message_id': messageId.toString(),
          'channel_id': channelId.toString(),
          'user_id': userId.toString(),
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete message: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Failed to delete message');
      }
    } catch (e) {
      throw Exception('Error deleting message: $e');
    }
  }

  static Future<void> editChannelMessage({
    required int messageId,
    required int channelId,
    required String newContent,
  }) async {
    try {
      final userId = await Storage.getUserId();
      final response = await http.post(
        Uri.parse('$baseUrl/messages/edit_channel_message.php'),
        body: {
          'message_id': messageId.toString(),
          'channel_id': channelId.toString(),
          'user_id': userId.toString(),
          'content': newContent,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to edit message: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Failed to edit message');
      }
    } catch (e) {
      throw Exception('Error editing message: $e');
    }
  }

  static Future<List<Reaction>> reactToChannelMessage({
    required int messageId,
    required String emoji,
  }) async {
    try {
      final token = await Storage.getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/channel_messages/add_reaction.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message_id': messageId,
          'emoji': emoji,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to react to message: \\${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Failed to react to message');
      }
      // Return the new reactions list
      return (data['reactions'] as List)
          .map((r) => Reaction.fromJson(r))
          .toList();
    } catch (e) {
      throw Exception('Error reacting to message: \\${e.toString()}');
    }
  }

  static Future<void> deleteChannelMessageForMe({
    required int messageId,
  }) async {
    try {
      final token = await Storage.getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/channel_messages/delete_for_me.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message_id': messageId,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete message: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (!data['success']) {
        throw Exception(data['message'] ?? 'Failed to delete message');
      }
    } catch (e) {
      throw Exception('Error deleting message: $e');
    }
  }

  static Future<List<String>> uploadChannelMedia(File file) async {
    try {
      final token = await Storage.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/channel_messages/upload_media.php'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Assuming API returns a list of file paths
          if (data['file_paths'] != null) {
            return List<String>.from(data['file_paths']);
          } else if (data['file_path'] != null) {
            return [data['file_path']];
          }
        }
        throw Exception(data['message'] ?? 'Media upload failed');
      } else {
        throw Exception('Media upload failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error uploading media: $e');
    }
  }

  static Future<void> sendChannelTextOrMediaMessage({
    required int channelId,
    required String message,
    List<String>? mediaFilePaths,
    int? replyToId,
  }) async {
    try {
      final token = await Storage.getToken();
      final url = Uri.parse('$baseUrl/channel_messages/send_message.php');
      final body = {
        'channel_id': channelId,
        'message': message,
        'has_media': (mediaFilePaths != null && mediaFilePaths.isNotEmpty) ? 1 : 0,
        'has_voice': 0,
      };
      if (mediaFilePaths != null && mediaFilePaths.isNotEmpty) {
        body['media_files'] = json.encode(mediaFilePaths);
      }
      if (replyToId != null) {
        body['reply_to_id'] = replyToId;
      }
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );
      final data = json.decode(response.body);
      if (response.statusCode != 200 || data['status'] != 'success') {
        throw Exception(data['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }
} 