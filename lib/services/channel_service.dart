import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';
import '../utils/storage.dart';
import '../config/api_config.dart';

class ChannelService {


  static Future<List<Channel>> getChannels() async {
    final token = await Storage.getToken();
    if (token == null) throw Exception('No token found');
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/channels/get_channels.php');
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
        final List<dynamic> channels = data['data'];
        return channels.map((c) => Channel.fromJson(c)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch channels');
      }
    } else {
      throw Exception('Failed to fetch channels: ${response.statusCode}');
    }
  }

  static Future<void> requestJoin(int channelId) async {
    final token = await Storage.getToken();
    if (token == null) throw Exception('No token found');
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/channels/request_join.php');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'channel_id': channelId}),
    );
    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return;
    } else {
      throw Exception(data['message'] ?? 'Failed to send join request');
    }
  }

  static Future<void> joinPublic(int channelId) async {
    final token = await Storage.getToken();
    if (token == null) throw Exception('No token found');
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/channels/join_public.php');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'channel_id': channelId}),
    );
    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return;
    } else {
      throw Exception(data['message'] ?? 'Failed to join channel');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllContacts() async {
    final token = await Storage.getToken();
    if (token == null) throw Exception('No token found');
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/messages/get_all_contacts.php');
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
        final List<dynamic> contacts = data['contacts'];
        return contacts.cast<Map<String, dynamic>>();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch contacts');
      }
    } else {
      throw Exception('Failed to fetch contacts: ${response.statusCode}');
    }
  }

  static Future<void> createChannel({
    required String name,
    required String description,
    required bool isPrivate,
    required List<int> memberIds,
  }) async {
    final token = await Storage.getToken();
    if (token == null) throw Exception('No token found');
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/channels/create.php');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': name,
        'description': description,
        'is_private': isPrivate ? 1 : 0,
        'members': memberIds,
      }),
    );
    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return;
    } else {
      throw Exception(data['message'] ?? 'Failed to create channel');
    }
  }

  static Future<bool> leaveChannel(int channelId) async {
    final token = await Storage.getToken();
    if (token == null) throw Exception('No token found');
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/channels/leave.php');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'channel_id': channelId}),
    );
    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return true;
    } else {
      throw Exception(data['message'] ?? 'Failed to leave channel');
    }
  }

  static Future<bool> giveAdmin(int channelId, int userId) async {
    final token = await Storage.getToken();
    if (token == null) throw Exception('No token found');
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/channels/give_admin.php');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'channel_id': channelId, 'user_id': userId}),
    );
    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return true;
    } else {
      throw Exception(data['message'] ?? 'Failed to assign admin');
    }
  }

  static Future<bool> deleteChannel(int channelId) async {
    final token = await Storage.getToken();
    if (token == null) throw Exception('No token found');
    final url = Uri.parse('${ApiConfig.apiBaseUrl}/channels/delete.php');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'channel_id': channelId}),
    );
    final data = json.decode(response.body);
    if (response.statusCode == 200 && data['status'] == 'success') {
      return true;
    } else {
      throw Exception(data['message'] ?? 'Failed to delete channel');
    }
  }
} 