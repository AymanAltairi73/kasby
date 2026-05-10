import 'package:get/get.dart';
import 'app_routes.dart';
import '../features/splash/presentation/views/splash_view.dart';
import '../features/onboarding/presentation/views/onboarding_view.dart';
import '../features/auth/presentation/views/login_view.dart';
import '../features/auth/presentation/views/register_view.dart';
import '../features/auth/presentation/views/otp_view.dart';
import '../features/auth/presentation/views/forgot_password_view.dart';
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
import '../features/home/presentation/views/points_view.dart';
// import '../features/home/presentation/views/services_view.dart';
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
import '../features/support/presentation/bindings/support_binding.dart';
import '../features/wallet/presentation/views/all_transactions_view.dart';
import '../features/wallet/presentation/views/transaction_details_view.dart';
import '../features/profile/presentation/views/agent_dashboard_view.dart';
import '../features/profile/presentation/views/profile_update_view.dart';
import '../features/qr_payment/presentation/views/qr_scanner_view.dart';
import '../features/qr_payment/presentation/views/my_qr_view.dart';

class AppPages {
  static const initial = Routes.splash;

  static final routes = [
    GetPage(name: Routes.splash, page: () => const SplashView()),
    GetPage(name: Routes.onboarding, page: () => const OnboardingView()),
    GetPage(name: Routes.login, page: () => const LoginView()),
    GetPage(name: Routes.register, page: () => const RegisterView()),
    GetPage(name: Routes.otp, page: () => const OtpView()),
    GetPage(
      name: Routes.forgotPassword,
      page: () => const ForgotPasswordView(),
    ),
    GetPage(name: Routes.home, page: () => const MainShellView()),
    GetPage(
      name: Routes.investmentPlans,
      page: () => const InvestmentPlansView(),
    ),
    GetPage(
      name: Routes.investmentDetails,
      page: () => const InvestmentDetailsView(),
    ),
    GetPage(name: Routes.myInvestments, page: () => const MyInvestmentsView()),
    GetPage(name: Routes.wallet, page: () => const WalletView()),
    GetPage(name: Routes.deposit, page: () => const DepositView()),
    GetPage(name: Routes.withdraw, page: () => const WithdrawView()),
    GetPage(name: Routes.agents, page: () => const AgentsView()),
    GetPage(name: Routes.spinWheel, page: () => const SpinWheelView()),
    GetPage(name: Routes.dailyCheckIn, page: () => const DailyCheckInView()),
    GetPage(name: Routes.subscription, page: () => const SubscriptionView()),
    GetPage(name: Routes.notifications, page: () => const NotificationsView()),
    GetPage(name: Routes.profile, page: () => const ProfileView()),
    GetPage(name: Routes.support, page: () => const SupportView()),
    GetPage(name: Routes.legal, page: () => const LegalView()),
    GetPage(name: Routes.points, page: () => const PointsView()),
    GetPage(name: Routes.agentDetails, page: () => const AgentDetailsView()),
    GetPage(name: Routes.transfer, page: () => const TransferView()),
    // GetPage(name: Routes.services, page: () => const ServicesView()),
    GetPage(name: Routes.loan, page: () => const LoanView()),
    GetPage(name: Routes.editProfile, page: () => const EditProfileView()),
    GetPage(name: Routes.friendRequests, page: () => const SocialNetworkView()),
    GetPage(name: Routes.agencyApply, page: () => const AgencyApplyView()),
    GetPage(name: Routes.myTeam, page: () => const MyTeamView()),
    GetPage(name: Routes.kyc, page: () => const KycView()),
    GetPage(
      name: Routes.changePassword,
      page: () => const ChangePasswordView(),
    ),
    GetPage(
      name: Routes.supportChat,
      page: () => const SupportChatView(),
      binding: SupportBinding(),
    ),
    GetPage(
      name: Routes.allTransactions,
      page: () => const AllTransactionsView(),
    ),
    GetPage(
      name: Routes.transactionDetails,
      page: () => const TransactionDetailsView(),
    ),
    GetPage(
      name: Routes.personalProfile,
      page: () => const PersonalProfileView(),
    ),
    GetPage(
      name: Routes.phoneVerification,
      page: () => const PhoneAuthView(),
    ),
    GetPage(
      name: Routes.lockScreen,
      page: () => const LockScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(name: Routes.agentDashboard, page: () => const AgentDashboardView()),
    GetPage(name: Routes.profileUpdate, page: () => const ProfileUpdateView()),
    GetPage(name: Routes.qrScanner, page: () => const QrScannerView()),
    GetPage(name: Routes.myQr, page: () => const MyQrView()),
  ];
}
