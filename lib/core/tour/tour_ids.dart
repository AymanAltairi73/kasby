/// Identifiers for scalable multi-feature product tours.
enum TourId {
  home('home', version: 2),
  investments('investments', version: 1),
  wallet('wallet', version: 1),
  marketplace('marketplace', version: 1),
  social('social', version: 1),
  qr('qr', version: 1),
  luckyWheel('lucky_wheel', version: 1),
  referral('referral', version: 1),
  profile('profile', version: 1);

  const TourId(this.storageKey, {required this.version});

  final String storageKey;
  final int version;

  /// Human-readable label key for settings / replay menu.
  String get labelKey => 'tour_label_$storageKey';
}
