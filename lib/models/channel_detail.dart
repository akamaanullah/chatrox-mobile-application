class ChannelDetail {
  final int id;
  final String name;
  final String description;
  final bool isPrivate;
  final String createdAt;
  final int memberCount;
  final int mediaCount;
  final ChannelCreator creator;
  final List<ChannelDetailMember> members;
  final List<ChannelDetailMedia> media;

  ChannelDetail({
    required this.id,
    required this.name,
    required this.description,
    required this.isPrivate,
    required this.createdAt,
    required this.memberCount,
    required this.mediaCount,
    required this.creator,
    required this.members,
    required this.media,
  });

  factory ChannelDetail.fromJson(Map<String, dynamic> json) {
    return ChannelDetail(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isPrivate: json['is_private'] == true || json['is_private'] == 1,
      createdAt: json['created_at'] ?? '',
      memberCount: json['member_count'] ?? 0,
      mediaCount: json['media_count'] ?? 0,
      creator: ChannelCreator.fromJson(json['creator']),
      members: (json['members'] as List?)?.map((m) => ChannelDetailMember.fromJson(m)).toList() ?? [],
      media: (json['media'] as List?)?.map((m) => ChannelDetailMedia.fromJson(m)).toList() ?? [],
    );
  }

  ChannelDetail copyWith({
    String? name,
    String? description,
    bool? isPrivate,
    String? createdAt,
    int? memberCount,
    int? mediaCount,
    ChannelCreator? creator,
    List<ChannelDetailMember>? members,
    List<ChannelDetailMedia>? media,
  }) {
    return ChannelDetail(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      mediaCount: mediaCount ?? this.mediaCount,
      creator: creator ?? this.creator,
      members: members ?? this.members,
      media: media ?? this.media,
    );
  }
}

class ChannelCreator {
  final int id;
  final String name;
  final String avatar;

  ChannelCreator({
    required this.id,
    required this.name,
    required this.avatar,
  });

  factory ChannelCreator.fromJson(Map<String, dynamic> json) {
    return ChannelCreator(
      id: json['id'],
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
    );
  }
}

class ChannelDetailMember {
  final int id;
  final String fullName;
  final String profilePicture;
  final String role;
  final String joinedAt;

  ChannelDetailMember({
    required this.id,
    required this.fullName,
    required this.profilePicture,
    required this.role,
    required this.joinedAt,
  });

  factory ChannelDetailMember.fromJson(Map<String, dynamic> json) {
    return ChannelDetailMember(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      profilePicture: json['profile_picture'] ?? '',
      role: json['role'] ?? '',
      joinedAt: json['joined_at'] ?? '',
    );
  }
}

class ChannelDetailMedia {
  final int id;
  final String filePath;
  final String fileType;
  final String uploadedAt;
  final int uploadedBy;
  final String uploadedByName;
  final String profilePicture;

  ChannelDetailMedia({
    required this.id,
    required this.filePath,
    required this.fileType,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.profilePicture,
  });

  factory ChannelDetailMedia.fromJson(Map<String, dynamic> json) {
    return ChannelDetailMedia(
      id: json['id'],
      filePath: json['file_path'] ?? '',
      fileType: json['file_type'] ?? '',
      uploadedAt: json['uploaded_at'] ?? '',
      uploadedBy: json['uploaded_by'] ?? 0,
      uploadedByName: json['uploaded_by_name'] ?? '',
      profilePicture: json['profile_picture'] ?? '',
    );
  }
} 