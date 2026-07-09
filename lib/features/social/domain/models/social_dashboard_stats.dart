class SocialDashboardStats {
  final int totalFriends;
  final int pendingIncoming;
  final int pendingOutgoing;
  final int newFriendsToday;
  final int messagesToday;
  final int onlineFriends;

  const SocialDashboardStats({
    this.totalFriends = 0,
    this.pendingIncoming = 0,
    this.pendingOutgoing = 0,
    this.newFriendsToday = 0,
    this.messagesToday = 0,
    this.onlineFriends = 0,
  });

  factory SocialDashboardStats.fromMap(Map<String, dynamic> map) {
    return SocialDashboardStats(
      totalFriends: map['total_friends'] as int? ?? 0,
      pendingIncoming: map['pending_incoming'] as int? ?? 0,
      pendingOutgoing: map['pending_outgoing'] as int? ?? 0,
      newFriendsToday: map['new_friends_today'] as int? ?? 0,
      messagesToday: map['messages_today'] as int? ?? 0,
      onlineFriends: map['online_friends'] as int? ?? 0,
    );
  }

  SocialDashboardStats copyWith({int? onlineFriends}) {
    return SocialDashboardStats(
      totalFriends: totalFriends,
      pendingIncoming: pendingIncoming,
      pendingOutgoing: pendingOutgoing,
      newFriendsToday: newFriendsToday,
      messagesToday: messagesToday,
      onlineFriends: onlineFriends ?? this.onlineFriends,
    );
  }
}
