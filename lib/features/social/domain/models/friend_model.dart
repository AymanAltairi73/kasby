class FriendModel {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? username;
  final DateTime? lastSeenAt;
  final DateTime? friendsSince;

  const FriendModel({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.username,
    this.lastSeenAt,
    this.friendsSince,
  });

  factory FriendModel.fromMap(Map<String, dynamic> map) {
    DateTime? lastSeen;
    final rawLastSeen = map['last_seen_at'];
    if (rawLastSeen != null) {
      lastSeen = DateTime.tryParse(rawLastSeen.toString());
    }

    DateTime? since;
    final rawSince = map['friends_since'];
    if (rawSince != null) {
      since = DateTime.tryParse(rawSince.toString());
    }

    return FriendModel(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString(),
      username: map['username']?.toString() ?? map['referral_code']?.toString(),
      lastSeenAt: lastSeen,
      friendsSince: since,
    );
  }
}
