import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_profile.dart';
import '../utils/storage.dart';
import '../config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService {
  static Future<UserProfile> getProfile() async {
    final token = await Storage.getToken();
    final url = Uri.parse(ApiConfig.getUserProfileEndpoint);
    print('Fetching profile with token: $token');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    
    print('Profile response status: ${response.statusCode}');
    print('Profile response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'success') {
        return UserProfile.fromJson(data);
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch profile');
      }
    } else {
      throw Exception('Failed to fetch profile');
    }
  }

  static Future<bool> updateBio(String bio) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final requestBody = json.encode({
        'bio': bio,
      });
      
      print('Updating bio with request: $requestBody');
      print('Token: $token');
      
      final response = await http.put(
        Uri.parse(ApiConfig.editBioEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      print('Bio update response status: ${response.statusCode}');
      print('Bio update response body: ${response.body}');

      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        return true;
      } else {
        print('Failed to update bio: ${data['message']}');
        return false;
      }
    } catch (e) {
      print('Error updating bio: $e');
      return false;
    }
  }

  static Future<bool> updateName(String firstName, String lastName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      final requestBody = json.encode({
        'first_name': firstName,
        'last_name': lastName,
      });
      
      print('Updating name with request: $requestBody');
      print('Token: $token');
      
      final response = await http.put(
        Uri.parse(ApiConfig.editNameEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: requestBody,
      );

      print('Name update response status: ${response.statusCode}');
      print('Name update response body: ${response.body}');

      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        return true;
      } else {
        print('Failed to update name: ${data['message']}');
        return false;
      }
    } catch (e) {
      print('Error updating name: $e');
      return false;
    }
  }
} 