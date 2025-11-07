class Channel {
  final int id;
  final String name;
  final String description;
  final bool isPrivate;
  final String createdAt;
  final String updatedAt;
  final String createdByName;
  final String createdByAvatar;
  final List<ChannelMember> members;
  final List<ChannelJoinRequest> joinRequests;
  final int memberCount;
  final String userRole;

  Channel({
    required this.id,
    required this.name,
    required this.description,
    required this.isPrivate,
    required this.createdAt,
    required this.updatedAt,
    required this.createdByName,
    required this.createdByAvatar,
    required this.members,
    required this.joinRequests,
    required this.memberCount,
    required this.userRole,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isPrivate: json['is_private'] == true || json['is_private'] == 1,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      createdByName: json['created_by_name'] ?? '',
      createdByAvatar: json['created_by_avatar'] ?? '',
      members: (json['members'] as List?)?.map((m) => ChannelMember.fromJson(m)).toList() ?? [],
      joinRequests: (json['join_requests'] as List?)?.map((j) => ChannelJoinRequest.fromJson(j)).toList() ?? [],
      memberCount: json['member_count'] ?? 0,
      userRole: json['user_role'] ?? '',
    );
  }
}

class ChannelMember {
  final int id;
  final String firstName;
  final String lastName;
  final String profilePicture;
  final String role;
  final String joinedAt;

  ChannelMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.profilePicture,
    required this.role,
    required this.joinedAt,
  });

  factory ChannelMember.fromJson(Map<String, dynamic> json) {
    return ChannelMember(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      profilePicture: json['profile_picture'] ?? '',
      role: json['role'] ?? '',
      joinedAt: json['joined_at'] ?? '',
    );
  }
}

class ChannelJoinRequest {
  final int id;
  final String firstName;
  final String lastName;
  final String profilePicture;
  final String status;
  final String requestedAt;

  ChannelJoinRequest({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.profilePicture,
    required this.status,
    required this.requestedAt,
  });

  factory ChannelJoinRequest.fromJson(Map<String, dynamic> json) {
    return ChannelJoinRequest(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      profilePicture: json['profile_picture'] ?? '',
      status: json['status'] ?? '',
      requestedAt: json['requested_at'] ?? '',
    );
  }
} 