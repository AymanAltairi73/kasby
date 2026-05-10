import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kasby/core/theme/app_theme.dart';
import 'package:kasby/routes/app_pages.dart';
import 'package:kasby/core/localization/kasby_translations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:kasby/features/auth/presentation/controllers/auth_controller.dart';
import 'package:kasby/core/controllers/currency_controller.dart';
import 'package:kasby/core/controllers/theme_controller.dart';
import 'package:kasby/features/home/presentation/controllers/home_controller.dart';
import 'package:kasby/features/profile/presentation/controllers/agent_controller.dart';
import 'package:kasby/core/controllers/shell_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:kasby/core/services/fcm_service.dart';
import 'package:kasby/firebase_options.dart';
import 'package:kasby/features/auth/domain/services/otp_service.dart';
import 'package:kasby/core/services/network_service.dart';
import 'package:kasby/core/widgets/connectivity_banner.dart';
import 'package:kasby/core/services/session_service.dart';
import 'package:kasby/core/services/confetti_service.dart';
import 'package:kasby/features/qr_payment/presentation/controllers/qr_payment_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Initialize Services
  await Get.putAsync(() => FCMService().init());
  await Get.putAsync(() => NetworkService().init());
  Get.put(OTPService(), permanent: true);

  Get.put(CurrencyController());
  Get.put(HomeController(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(ThemeController(), permanent: true);
  Get.put(ShellController(), permanent: true);
  Get.put(SessionService(), permanent: true);
  Get.put(ConfettiService(), permanent: true);
  Get.lazyPut(() => AgentController());
  Get.lazyPut(() => QrPaymentController(), fenix: true);
  runApp(const KasbyApp());
}

class KasbyApp extends StatelessWidget {
  const KasbyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isDark = ThemeController.to.isDark.value;
      return GetMaterialApp(
        title: 'Kasby',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
        translations: KasbyTranslations(),
        locale: const Locale('ar', 'SA'),
        fallbackLocale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US'), Locale('ar', 'SA')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        defaultTransition: Transition.fade,
        builder: (context, child) {
          return Stack(
            children: [
              ConnectivityBanner(child: child ?? const SizedBox.shrink()),
              ConfettiService.to.buildConfetti(),
            ],
          );
        },
      );
    });
  }
}
