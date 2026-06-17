import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/features/support/presentation/controllers/support_chat_controller.dart';
import 'app_routes.dart';
import '../features/splash/presentation/views/splash_view.dart';
import '../features/onboarding/presentation/views/onboarding_view.dart';
import '../features/auth/presentation/views/login_view.dart';
import '../features/auth/presentation/views/register_view.dart';
import '../features/auth/presentation/views/otp_view.dart';
import '../features/auth/presentation/views/forgot_password_view.dart';
import '../features/auth/presentation/views/verify_email_view.dart';
import '../features/auth/presentation/views/phone_auth_view.dart';
import '../features/home/presentation/views/main_shell_view.dart';
import '../features/investment/presentation/views/investment_plans_view.dart';
import '../features/investment/presentation/views/investment_details_view.dart';
import '../features/wallet/presentation/views/wallet_view.dart';
import '../features/wallet/presentation/views/deposit_view.dart';
import '../features/wallet/presentation/views/withdraw_view.dart';
import '../features/wallet/presentation/views/agents_view.dart';
import '../features/wallet/presentation/views/agent_details_view.dart';
import '../features/wallet/presentation/views/transfer_view.dart';
import '../features/home/presentation/views/spin_wheel_view.dart';
import '../features/home/presentation/views/daily_check_in_view.dart';
import '../features/home/presentation/views/subscription_view.dart';
import '../features/home/presentation/views/notifications_view.dart';
import '../features/profile/presentation/views/profile_view.dart';
import '../features/profile/presentation/views/support_view.dart';
import '../features/profile/presentation/views/legal_view.dart';
import '../features/investment/presentation/views/my_investments_view.dart';
import '../features/home/presentation/views/ksp_wallet_view.dart';
import '../features/wallet/presentation/views/loan_view.dart';
import '../features/profile/presentation/views/edit_profile_view.dart';
import '../features/profile/presentation/views/personal_profile_view.dart';
import '../core/widgets/lock_screen.dart';
import '../features/profile/presentation/views/social_network_view.dart';
import '../features/wallet/presentation/views/agency_apply_view.dart';
import '../features/profile/presentation/views/my_team_view.dart';
import '../features/profile/presentation/views/kyc_view.dart';
import '../features/profile/presentation/views/change_password_view.dart';
import '../features/support/presentation/views/support_chat_view.dart';
import '../features/wallet/presentation/views/all_transactions_view.dart';
import '../features/wallet/presentation/views/transaction_details_view.dart';
import '../features/profile/presentation/views/agent_dashboard_view.dart';
import '../features/profile/presentation/views/profile_update_view.dart';
import '../features/qr_payment/presentation/views/qr_scanner_view.dart';
import '../features/qr_payment/presentation/views/my_qr_view.dart';
import '../features/profile/presentation/views/security_center_view.dart';
import '../features/wallet/presentation/views/statements_view.dart';
import '../features/investment/presentation/views/recurring_investments_view.dart';
import '../features/investment/presentation/views/create_recurring_investment_view.dart';
import '../features/referral/presentation/views/referral_analytics_view.dart';
import '../features/onboarding/presentation/views/guided_tour_view.dart';
import '../features/portfolio/presentation/views/portfolio_analytics_view.dart';
import '../features/search/presentation/views/global_search_view.dart';
import '../features/home/presentation/views/notification_preferences_view.dart';

class AppPages {
  static const initial = Routes.splash;

  static Widget _loggedScreen(String screenName, Widget child) {
    return TrackedScreen(screenName: screenName, child: child);
  }

  static GetPage _route(
    String name,
    String screen,
    Widget Function() builder, {
    Bindings? binding,
    Transition? transition,
  }) {
    return GetPage(
      name: name,
      page: () => _loggedScreen(screen, builder()),
      binding: binding,
      transition: transition,
    );
  }

  static final routes = [
    _route(Routes.splash, 'SplashView', () => const SplashView()),
    _route(Routes.onboarding, 'OnboardingView', () => const OnboardingView()),
    _route(Routes.login, 'LoginView', () => const LoginView()),
    _route(Routes.register, 'RegisterView', () => const RegisterView()),
    _route(Routes.otp, 'OtpView', () => const OtpView()),
    _route(
      Routes.forgotPassword,
      'ForgotPasswordView',
      () => const ForgotPasswordView(),
    ),
    _route(
      Routes.verifyEmail,
      'VerifyEmailView',
      () => const VerifyEmailView(),
    ),
    _route(Routes.home, 'MainShellView', () => const MainShellView()),
    _route(
      Routes.investmentPlans,
      'InvestmentPlansView',
      () => const InvestmentPlansView(),
    ),
    _route(
      Routes.investmentDetails,
      'InvestmentDetailsView',
      () => const InvestmentDetailsView(),
    ),
    _route(
      Routes.myInvestments,
      'MyInvestmentsView',
      () => const MyInvestmentsView(),
    ),
    _route(Routes.wallet, 'WalletView', () => const WalletView()),
    _route(Routes.deposit, 'DepositView', () => const DepositView()),
    _route(Routes.withdraw, 'WithdrawView', () => const WithdrawView()),
    _route(Routes.agents, 'AgentsView', () => const AgentsView()),
    _route(Routes.spinWheel, 'SpinWheelView', () => const SpinWheelView()),
    _route(
      Routes.dailyCheckIn,
      'DailyCheckInView',
      () => const DailyCheckInView(),
    ),
    _route(
      Routes.subscription,
      'SubscriptionView',
      () => const SubscriptionView(),
    ),
    _route(
      Routes.notifications,
      'NotificationsView',
      () => const NotificationsView(),
    ),
    _route(Routes.profile, 'ProfileView', () => const ProfileView()),
    _route(Routes.support, 'SupportView', () => const SupportView()),
    _route(Routes.legal, 'LegalView', () => const LegalView()),
    _route(Routes.kspWallet, 'KspWalletView', () => const KspWalletView()),
    _route(
      Routes.agentDetails,
      'AgentDetailsView',
      () => const AgentDetailsView(),
    ),
    _route(Routes.transfer, 'TransferView', () => const TransferView()),
    _route(Routes.loan, 'LoanView', () => const LoanView()),
    _route(
      Routes.editProfile,
      'EditProfileView',
      () => const EditProfileView(),
    ),
    _route(
      Routes.friendRequests,
      'SocialNetworkView',
      () => const SocialNetworkView(),
    ),
    _route(
      Routes.agencyApply,
      'AgencyApplyView',
      () => const AgencyApplyView(),
    ),
    _route(Routes.myTeam, 'MyTeamView', () => const MyTeamView()),
    _route(Routes.kyc, 'KycView', () => const KycView()),
    _route(
      Routes.changePassword,
      'ChangePasswordView',
      () => const ChangePasswordView(),
    ),
    _route(
      Routes.supportChat,
      'SupportChatView',
      () => const SupportChatView(),
      binding: BindingsBuilder(() {
        final args = Get.arguments;
        final map = args is Map<String, dynamic> ? args : null;
        Get.lazyPut(
          () => SupportChatController(
            predefinedConversationId: map?['conversation_id'] as String?,
          ),
          fenix: true,
        );
      }),
    ),
    _route(
      Routes.socialChat,
      'SupportChatView',
      () => const SupportChatView(),
      binding: BindingsBuilder(() {
        final args = Get.arguments;
        final map = args is Map<String, dynamic> ? args : null;
        Get.lazyPut(
          () => SupportChatController(
            friendId: map?['friendId'] as String?,
            friendName: map?['friendName'] as String?,
            agentUserId: map?['user_id'] as String?,
            agentName: map?['user_name'] as String?,
            isAgentChat: map?['is_agent_chat'] as bool? ?? false,
            predefinedConversationId: map?['conversation_id'] as String?,
          ),
        );
      }),
    ),
    _route(
      Routes.allTransactions,
      'AllTransactionsView',
      () => const AllTransactionsView(),
    ),
    _route(
      Routes.transactionDetails,
      'TransactionDetailsView',
      () => const TransactionDetailsView(),
    ),
    _route(
      Routes.personalProfile,
      'PersonalProfileView',
      () => const PersonalProfileView(),
    ),
    _route(
      Routes.phoneVerification,
      'PhoneAuthView',
      () => const PhoneAuthView(),
    ),
    _route(
      Routes.lockScreen,
      'LockScreen',
      () => const LockScreen(),
      transition: Transition.fadeIn,
    ),
    _route(
      Routes.agentDashboard,
      'AgentDashboardView',
      () => const AgentDashboardView(),
    ),
    _route(
      Routes.profileUpdate,
      'ProfileUpdateView',
      () => const ProfileUpdateView(),
    ),
    _route(Routes.qrScanner, 'QrScannerView', () => const QrScannerView()),
    _route(Routes.myQr, 'MyQrView', () => const MyQrView()),
    _route(
      Routes.securityCenter,
      'SecurityCenterView',
      () => const SecurityCenterView(),
    ),
    _route(Routes.statements, 'StatementsView', () => const StatementsView()),
    _route(
      Routes.portfolioAnalytics,
      'PortfolioAnalyticsView',
      () => const PortfolioAnalyticsView(),
    ),
    _route(
      Routes.guidedTour,
      'GuidedTourView',
      () => const GuidedTourView(),
      transition: Transition.fadeIn,
    ),
    _route(
      Routes.globalSearch,
      'GlobalSearchView',
      () => const GlobalSearchView(),
      transition: Transition.fadeIn,
    ),
    _route(
      Routes.referralAnalytics,
      'ReferralAnalyticsView',
      () => const ReferralAnalyticsView(),
    ),
    _route(
      Routes.recurringInvestments,
      'RecurringInvestmentsView',
      () => const RecurringInvestmentsView(),
    ),
    _route(
      Routes.createRecurringInvestment,
      'CreateRecurringInvestmentView',
      () => const CreateRecurringInvestmentView(),
    ),
    _route(
      Routes.notificationPreferences,
      'NotificationPreferencesView',
      () => const NotificationPreferencesView(),
    ),
  ];
}
