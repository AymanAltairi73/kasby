/// Named breadcrumb events for Crashlytics timeline reconstruction.
/// Use [CrashReportingService.log] with these constants — never log sensitive data.
abstract final class CrashBreadcrumb {
  // Authentication
  static const loginStarted = 'Login started';
  static const loginCompleted = 'Login completed';
  static const loginFailed = 'Login failed';
  static const logout = 'Logout';
  static const registrationStarted = 'Registration started';
  static const registrationCompleted = 'Registration completed';
  static const passwordResetStarted = 'Password reset started';
  static const passwordResetCompleted = 'Password reset completed';
  static const otpVerificationStarted = 'OTP verification started';
  static const otpVerificationCompleted = 'OTP verification completed';

  // Wallet
  static const depositStarted = 'Deposit started';
  static const depositCompleted = 'Deposit completed';
  static const withdrawalStarted = 'Withdrawal started';
  static const withdrawalCompleted = 'Withdrawal completed';
  static const transferStarted = 'Transfer started';
  static const transferCompleted = 'Transfer completed';

  // Marketplace / KSP
  static const productOpened = 'Product opened';
  static const addedToCart = 'Added to cart';
  static const checkoutStarted = 'Checkout started';
  static const paymentCompleted = 'Payment completed';

  // Investments
  static const investmentCreated = 'Investment created';
  static const investmentCancelled = 'Investment cancelled';
  static const roiViewed = 'ROI viewed';
  static const loanRequested = 'Loan requested';

  // Profile
  static const profileUpdated = 'Profile updated';
  static const phoneChanged = 'Phone changed';
  static const emailChanged = 'Email changed';

  // Referral
  static const referralApplied = 'Referral applied';

  // Navigation
  static const screenOpened = 'Screen opened';
}

abstract final class CrashCustomKey {
  static const errorCategory = 'error_category';
  static const authMethod = 'auth_method';
  static const loginType = 'login_type';
  static const walletBalanceRange = 'wallet_balance_range';
  static const transactionType = 'transaction_type';
  static const productId = 'product_id';
  static const category = 'category';
  static const orderStatus = 'order_status';
  static const investmentPlan = 'investment_plan';
  static const investmentStatus = 'investment_status';
  static const referralLevel = 'referral_level';
  static const screenName = 'screen_name';
  static const currentRoute = 'current_route';
  static const appVersion = 'app_version';
  static const buildNumber = 'build_number';
  static const userRole = 'user_role';
  static const accountType = 'account_type';
  static const kycStatus = 'kyc_status';
  static const country = 'country';
  static const supabaseErrorType = 'supabase_error_type';
  static const rpcName = 'rpc_name';
  static const tableName = 'table_name';
  static const httpStatus = 'http_status';
  static const postgrestCode = 'postgrest_code';
  static const connectionQuality = 'connection_quality';
  static const isConnected = 'is_connected';
}
