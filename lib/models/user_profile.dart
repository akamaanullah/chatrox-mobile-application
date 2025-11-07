class UserProfile {
  final int id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String phone;
  final String about;
  final String profilePicture;
  final int companyId;
  final String companyName;
  final String createdAt;
  final String lastActive;
  final List<UserChannel> channels;

  UserProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.about,
    required this.profilePicture,
    required this.companyId,
    required this.companyName,
    required this.createdAt,
    required this.lastActive,
    required this.channels,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    print('Parsing UserProfile from JSON: $json');
    
    // Get user data from the correct path
    final userData = json['data']?['user'] ?? json['user'] ?? json;
    print('User data to parse: $userData');
    
    try {
      return UserProfile(
        id: userData['id'] is int ? userData['id'] : int.tryParse(userData['id'].toString()) ?? 0,
        firstName: userData['first_name']?.toString() ?? '',
        lastName: userData['last_name']?.toString() ?? '',
        fullName: userData['full_name']?.toString() ?? '',
        email: userData['email']?.toString() ?? '',
        phone: userData['phone']?.toString() ?? '',
        about: userData['bio']?.toString() ?? userData['about']?.toString() ?? '',
        profilePicture: userData['profile_picture']?.toString() ?? '',
        companyId: userData['company_id'] is int ? userData['company_id'] : int.tryParse(userData['company_id'].toString()) ?? 0,
        companyName: userData['company_name']?.toString() ?? '',
        createdAt: userData['created_at']?.toString() ?? '',
        lastActive: userData['last_active']?.toString() ?? '',
        channels: (json['data']?['channels'] as List?)?.map((c) => UserChannel.fromJson(c)).toList() ?? 
                 (json['channels'] as List?)?.map((c) => UserChannel.fromJson(c)).toList() ?? [],
      );
    } catch (e) {
      print('Error parsing UserProfile: $e');
      rethrow;
    }
  }

  UserProfile copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? fullName,
    String? email,
    String? phone,
    String? about,
    String? profilePicture,
    int? companyId,
    String? companyName,
    String? createdAt,
    String? lastActive,
    List<UserChannel>? channels,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      about: about ?? this.about,
      profilePicture: profilePicture ?? this.profilePicture,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      createdAt: createdAt ?? this.createdAt,
      lastActive: lastActive ?? this.lastActive,
      channels: channels ?? this.channels,
    );
  }
}

class UserChannel {
  final int id;
  final String name;

  UserChannel({required this.id, required this.name});

  factory UserChannel.fromJson(Map<String, dynamic> json) {
    return UserChannel(
      id: json['id'],
      name: json['name'] ?? '',
    );
  }
} 