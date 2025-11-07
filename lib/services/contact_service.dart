import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/contact.dart';
import '../utils/storage.dart';
import '../config/api_config.dart';

class ContactService {


  static Future<List<Contact>> getAllContacts() async {
    try {
      final token = await Storage.getToken();
      if (token == null) throw Exception('No token found');
      final response = await http.get(
        Uri.parse('${ApiConfig.apiBaseUrl}/messages/get_all_contacts.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API contacts response: ' + response.body.toString());
        if (data['status'] == 'success') {
          final List<dynamic> contacts = data['contacts'];
          return contacts.map((c) => Contact.fromJson(c)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch contacts');
        }
      } else {
        throw Exception('Failed to fetch contacts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching contacts: $e');
    }
  }
} 