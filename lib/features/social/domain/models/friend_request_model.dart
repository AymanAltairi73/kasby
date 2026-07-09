class FriendRequestModel {
  final String requestId;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String? username;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final int mutualFriends;
  final bool isOutgoing;

  const FriendRequestModel({
    required this.requestId,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.username,
    this.createdAt,
    this.lastSeenAt,
    this.mutualFriends = 0,
    this.isOutgoing = false,
  });

  factory FriendRequestModel.fromMap(
    Map<String, dynamic> map, {
    required bool outgoing,
  }) {
    DateTime? created;
    final rawCreated = map['created_at'];
    if (rawCreated != null) {
      created = DateTime.tryParse(rawCreated.toString());
    }

    DateTime? lastSeen;
    final rawLastSeen = map['last_seen_at'];
    if (rawLastSeen != null) {
      lastSeen = DateTime.tryParse(rawLastSeen.toString());
    }

    return FriendRequestModel(
      requestId: map['request_id']?.toString() ?? '',
      userId: outgoing
          ? map['receiver_id']?.toString() ?? ''
          : map['requester_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString(),
      username: map['username']?.toString() ?? map['referral_code']?.toString(),
      createdAt: created,
      lastSeenAt: lastSeen,
      mutualFriends: map['mutual_friends'] as int? ?? 0,
      isOutgoing: outgoing,
    );
  }
}
