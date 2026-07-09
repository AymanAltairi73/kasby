class SocialUserModel {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? username;
  final DateTime? lastSeenAt;
  final int mutualFriends;
  final bool isFriend;
  final bool requestSent;
  final bool requestReceived;

  const SocialUserModel({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.username,
    this.lastSeenAt,
    this.mutualFriends = 0,
    this.isFriend = false,
    this.requestSent = false,
    this.requestReceived = false,
  });

  factory SocialUserModel.fromMap(Map<String, dynamic> map) {
    DateTime? lastSeen;
    final rawLastSeen = map['last_seen_at'];
    if (rawLastSeen != null) {
      lastSeen = DateTime.tryParse(rawLastSeen.toString());
    }

    return SocialUserModel(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString(),
      username: map['username']?.toString() ?? map['referral_code']?.toString(),
      lastSeenAt: lastSeen,
      mutualFriends: map['mutual_friends'] as int? ?? 0,
      isFriend: map['is_friend'] == true,
      requestSent: map['request_sent'] == true,
      requestReceived: map['request_received'] == true,
    );
  }

  SocialUserModel copyWith({
    bool? requestSent,
    bool? requestReceived,
    bool? isFriend,
  }) {
    return SocialUserModel(
      id: id,
      fullName: fullName,
      avatarUrl: avatarUrl,
      username: username,
      lastSeenAt: lastSeenAt,
      mutualFriends: mutualFriends,
      isFriend: isFriend ?? this.isFriend,
      requestSent: requestSent ?? this.requestSent,
      requestReceived: requestReceived ?? this.requestReceived,
    );
  }
}
