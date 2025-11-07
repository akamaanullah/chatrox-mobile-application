import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel_detail.dart';
import '../utils/storage.dart';

class ChannelDetailService {
  static const String baseUrl = 'http://172.16.32.59:8886/chatrox-api';

  static Future<ChannelDetail> getChannelDetail(int channelId) async {
    final token = await Storage.getToken();
    if (token == null) throw Exception('No token found');
    final url = Uri.parse('$baseUrl/channels/get_channel_details.php?channel_id=$channelId');
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
        return ChannelDetail.fromJson(data['data']['channel']);
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch channel detail');
      }
    } else {
      throw Exception('Failed to fetch channel detail: \\${response.statusCode}');
    }
  }
} 