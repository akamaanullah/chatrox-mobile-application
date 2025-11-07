import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recent_message.dart';
import '../models/chat_message.dart';
import '../utils/storage.dart';
import '../config/api_config.dart';

class MessageService {

  static Future<List<RecentMessage>> getRecentMessages() async {
    try {
      final token = await Storage.getToken();
    
      final url = ApiConfig.getRecentMessagesEndpoint;
    
      if (token == null) throw Exception('No token found');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final List<dynamic> messages = data['data'];
          return messages.map((msg) => RecentMessage.fromJson(msg)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch messages');
        }
      } else {
        throw Exception('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (e) {
  
      throw Exception('Error fetching recent messages: $e');
    }
  }

  static Future<Map<String, List<ChatMessage>>> getChatMessages({
    required int chatId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final token = await Storage.getToken();
      if (token == null) throw Exception('No token found');
      final response = await http.get(
        Uri.parse('${ApiConfig.getUserMessagesEndpoint}?chat_id=$chatId&limit=$limit&offset=$offset'),
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
              "Messages": (raw as List).map((m) => ChatMessage.fromJson(m)).toList(),
            };
          } else if (raw is Map<String, dynamic>) {
            // Grouped hai
            return raw.map((date, msgs) => MapEntry(
              date,
              (msgs as List).map((m) => ChatMessage.fromJson(m)).toList(),
            ));
          } else {
            return {};
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch messages');
        }
      } else {
        throw Exception('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching chat messages: $e');
    }
  }
} 