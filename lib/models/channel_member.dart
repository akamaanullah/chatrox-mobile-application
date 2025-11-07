class ChannelMember {
  final int id;
  final String fullName;
  final String? profilePicture;
  final String role;

  ChannelMember({
    required this.id,
    required this.fullName,
    this.profilePicture,
    required this.role,
  });

  factory ChannelMember.fromJson(Map<String, dynamic> json) {
    return ChannelMember(
      id: json['id'],
      fullName: json['full_name'],
      profilePicture: json['profile_picture'],
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'profile_picture': profilePicture,
      'role': role,
    };
  }
} 