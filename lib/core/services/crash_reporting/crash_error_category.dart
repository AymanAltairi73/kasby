/// Error classification for Crashlytics diagnostics.
enum CrashErrorCategory {
  authentication('authentication'),
  wallet('wallet'),
  marketplace('marketplace'),
  investments('investments'),
  notifications('notifications'),
  profile('profile'),
  admin('admin'),
  database('database'),
  network('network'),
  supabase('supabase'),
  unknown('unknown');

  const CrashErrorCategory(this.key);
  final String key;
}
