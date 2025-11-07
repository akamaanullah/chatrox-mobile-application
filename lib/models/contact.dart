import '../config/api_config.dart';

class Contact {
  final int id;
  final String firstName;
  final String lastName;
  final String username;
  final String? profilePicture;

  Contact({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    this.profilePicture,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    String? profilePic = json['profile_picture'];
    if (profilePic != null && profilePic.isNotEmpty && !profilePic.startsWith('http')) {
      if (!profilePic.startsWith('/')) {
        profilePic = '/$profilePic';
      }
      profilePic = ApiConfig.getAssetUrl(profilePic);
    }

    String fullName = json['full_name'] ?? '';
    String firstName = '';
    String lastName = '';
    if (fullName.isNotEmpty) {
      var parts = fullName.trim().split(' ');
      firstName = parts.first;
      if (parts.length > 1) {
        lastName = parts.sublist(1).join(' ');
      }
    }

    return Contact(
      id: int.parse(json['id'].toString()),
      firstName: firstName,
      lastName: lastName,
      username: json['username'] ?? '',
      profilePicture: profilePic,
    );
  }

  String get displayName => (firstName + ' ' + lastName).trim().isNotEmpty
      ? (firstName + ' ' + lastName).trim()
      : username;

  String get avatarUrl => profilePicture ?? '';
} 