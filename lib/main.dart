import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kasby/core/theme/app_theme.dart';
import 'package:kasby/routes/app_pages.dart';
import 'package:kasby/core/localization/kasby_translations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/controllers/theme_controller.dart';
import 'package:kasby/core/services/ksp_balance_service.dart';
import 'package:kasby/core/services/currency_conversion_service.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/profile/presentation/controllers/agent_controller.dart';
import 'package:kasby/core/controllers/shell_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/firebase_options.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';
import 'package:kasby/features/auth/domain/services/email_otp_service.dart';
import 'package:kasby/features/auth/domain/services/phone_otp_service.dart';
import 'package:kasby/features/auth/domain/repositories/authentication_repository.dart';
import 'package:kasby/core/services/security_notification_service.dart';
import 'package:kasby/core/services/authentication_logger.dart';
import 'package:kasby/core/services/network_service.dart';
import 'package:kasby/core/services/account_restriction_service.dart';
import 'package:kasby/core/widgets/account_restriction_banner.dart';
import 'package:kasby/core/widgets/connectivity_banner.dart';
import 'package:kasby/core/services/sensitive_operation_guard.dart';
import 'package:kasby/core/services/transaction_auth_service.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/core/services/biometric_login_service.dart';
import 'package:kasby/core/services/security_activity_service.dart';
import 'package:kasby/core/utils/accessibility_utils.dart';
import 'package:kasby/core/services/confetti_service.dart';
import 'package:kasby/core/services/sound_service.dart';
import 'package:kasby/features/qr_payment/presentation/controllers/qr_payment_controller.dart';
import 'package:kasby/core/services/presence_service.dart';
import 'package:kasby/core/services/app_version_service.dart';
import 'package:kasby/core/services/deep_link_service.dart';
import 'package:kasby/core/utils/locale_helper.dart';
import 'package:kasby/core/services/app_lifecycle_lock_service.dart';
import 'package:kasby/core/services/supabase_service.dart';
import 'package:kasby/core/services/crash_reporting_service.dart';
import 'package:kasby/core/widgets/app_error_widget.dart';
import 'package:kasby/core/utils/safe_getx.dart';
import 'package:kasby/core/tour/tour_controller.dart';

void main() {
  CrashReportingService.runAppWithCrashGuards(_bootstrap);
}

Future<void> _bootstrap() async {
  final startupStopwatch = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize locale-aware date/number symbol data (H7) for ar/en formatting.
  await initializeDateFormatting();

  SafeGetx.debugTrace(
    className: 'main',
    method: 'startup',
    feature: 'Startup',
    status: 'INFO',
    message: 'App startup initiated',
  );

  ErrorWidget.builder = (details) => AppErrorWidget(details: details);

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await CrashReportingService.initialize(firebaseReady: true);
    SafeGetx.debugTrace(
      className: 'main',
      method: 'initFirebase',
      feature: 'Startup',
      status: 'SUCCESS',
      durationMs: startupStopwatch.elapsedMilliseconds,
    );
  } catch (e, st) {
    SafeGetx.debugTrace(
      className: 'main',
      method: 'initFirebase',
      feature: 'Startup',
      status: 'FAILED',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Load environment variables
  await dotenv.load(fileName: '.env');
  SafeGetx.debugTrace(
    className: 'main',
    method: 'loadEnv',
    feature: 'Startup',
    status: 'SUCCESS',
  );

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      publishableKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    SafeGetx.debugTrace(
      className: 'main',
      method: 'initSupabase',
      feature: 'Startup',
      status: 'SUCCESS',
      durationMs: startupStopwatch.elapsedMilliseconds,
    );
    SupabaseService.registerAuthListener();
  } catch (e, st) {
    SafeGetx.debugTrace(
      className: 'main',
      method: 'initSupabase',
      feature: 'Startup',
      status: 'FAILED',
      error: e,
      stackTrace: st,
    );
    rethrow;
  }

  // Initialize Services
  SafeGetx.debugTrace(
    className: 'main',
    method: 'initDependencyInjection',
    feature: 'Startup',
    status: 'INFO',
    message: 'Registering GetX services and controllers',
  );
  await Get.putAsync(() => FCMService().init());
  await Get.putAsync(() => NetworkService().init());
  await Get.putAsync(() => PresenceService().init(), permanent: true);
  await AuthenticationLogger.init();
  Get.put(EmailOtpService(), permanent: true);
  Get.put(PhoneOtpService(), permanent: true);
  Get.put(AuthenticationRepository(), permanent: true);
  Get.put(OTPService(), permanent: true);
  Get.put(SecurityNotificationService(), permanent: true);
  Get.put(SensitiveOperationGuardService(), permanent: true);
  Get.put(TransactionAuthService(), permanent: true);

  Get.put(CurrencyController());
  Get.put(KspBalanceService(), permanent: true);
  Get.put(CurrencyConversionService(), permanent: true);
  Get.put(HomeController(), permanent: true);
  Get.put(AccountRestrictionService(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(ThemeController(), permanent: true);
  Get.put(ShellController(), permanent: true);
  Get.put(TourController(), permanent: true);
  Get.put(SessionService(), permanent: true);
  Get.put(BiometricLoginService(), permanent: true);
  Get.put(AppLifecycleLockService(), permanent: true);
  Get.put(SecurityActivityService(), permanent: true);
  Get.put(ConfettiService(), permanent: true);
  Get.put(SoundService(), permanent: true);
  Get.lazyPut(() => AgentController());
  Get.lazyPut(() => QrPaymentController(), fenix: true);
  Get.put(AppVersionService(), permanent: true);
  await Get.putAsync(() => DeepLinkService().init(), permanent: true);

  final savedLocale = await LocaleHelper.getLanguageCode();
  final initialLocale = savedLocale == 'en'
      ? const Locale('en', 'US')
      : const Locale('ar', 'SA');

  SafeGetx.debugTrace(
    className: 'main',
    method: 'runApp',
    feature: 'Startup',
    status: 'SUCCESS',
    durationMs: startupStopwatch.elapsedMilliseconds,
    params: {'locale': initialLocale.toString()},
  );

  runApp(KasbyApp(initialLocale: initialLocale));
}

class KasbyApp extends StatefulWidget {
  final Locale initialLocale;

  const KasbyApp({super.key, required this.initialLocale});

  @override
  State<KasbyApp> createState() => _KasbyAppState();
}

class _KasbyAppState extends State<KasbyApp> {
  @override
  void initState() {
    super.initState();
    SafeGetx.debugTrace(
      className: 'KasbyApp',
      method: 'initState',
      feature: 'Startup',
      status: 'SUCCESS',
      message: 'GetMaterialApp initialized',
    );
    ThemeController.to.updateLanguage(widget.initialLocale.languageCode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppVersionService.to.checkForUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = ThemeController.to.isDark.value;
      final isEn = ThemeController.to.isEnglish;
      return GetMaterialApp(
        title: 'Kasby',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.getLightTheme(isEnglish: isEn),
        darkTheme: AppTheme.getDarkTheme(isEnglish: isEn),
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        routingCallback: SafeGetx.logRoute,
        translations: KasbyTranslations(),
        locale: widget.initialLocale,
        fallbackLocale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US'), Locale('ar', 'SA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        defaultTransition: Transition.fade,
        builder: (context, child) {
          return MediaQuery(
            data: AccessibilityUtils.clampTextScale(context),
            child: Stack(
              children: [
                AccountRestrictionBanner(
                  child: ConnectivityBanner(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
                ConfettiService.to.buildConfetti(),
              ],
            ),
          );
        },
      );
    });
  }
}
