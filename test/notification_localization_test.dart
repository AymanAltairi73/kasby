import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/profile_model.dart';
import 'package:kasby/core/models/notification_model.dart';
import 'package:kasby/core/localization/content_localization_service.dart';
import 'package:kasby/core/localization/kasby_translations.dart';
import 'package:get/get.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    Get.addTranslations(KasbyTranslations().keys);
  });

  group('ProfileModel language field', () {
    test('defaults to ar when language is null in json', () {
      final json = {
        'id': 'u1',
        'full_name': 'Test User',
        'role': 'user',
      };
      final p = ProfileModel.fromJson(json);
      expect(p.language, 'ar');
    });

    test('parses en language when present', () {
      final json = {
        'id': 'u1',
        'full_name': 'Test User',
        'role': 'user',
        'language': 'en',
      };
      final p = ProfileModel.fromJson(json);
      expect(p.language, 'en');
      expect(p.toJson()['language'], 'en');
    });

    test('copyWith updates language', () {
      final p = ProfileModel(id: 'u1', fullName: 'User', role: 'user', language: 'ar');
      final p2 = p.copyWith(language: 'en');
      expect(p2.language, 'en');
    });
  });

  group('NotificationModel localization fields', () {
    test('parses title_key, message_key, parameters map', () {
      final json = {
        'id': 'n1',
        'title': 'أرباح جديدة',
        'message': 'تم إضافة ربح بقيمة \$10 من استثمار (الذهب) بنجاح',
        'title_key': 'notif_daily_profit_received_title',
        'message_key': 'notif_daily_profit_received_msg',
        'parameters': {'amount': '\$10', 'plan': 'Gold Plan'},
      };
      final n = NotificationModel.fromJson(json);
      expect(n.titleKey, 'notif_daily_profit_received_title');
      expect(n.messageKey, 'notif_daily_profit_received_msg');
      expect(n.parameters?['amount'], '\$10');
      expect(n.parameters?['plan'], 'Gold Plan');
    });

    test('parses parameters when passed as JSON string', () {
      final json = {
        'id': 'n2',
        'title': 'Test',
        'message': 'Test Msg',
        'title_key': 'notif_ksp_redeem_success_title',
        'message_key': 'notif_ksp_redeem_success_msg',
        'parameters': '{"points":"100","amount":"\$5"}',
      };
      final n = NotificationModel.fromJson(json);
      expect(n.parameters?['points'], '100');
      expect(n.parameters?['amount'], '\$5');
    });
  });

  group('ContentLocalizationService key resolution', () {
    test('resolves notification with keys in English', () {
      Get.updateLocale(const Locale('en', 'US'));

      final n = NotificationModel(
        id: 'n1',
        title: 'أرباح يومية',
        message: 'تم إضافة ربح',
        titleKey: 'notif_daily_profit_received_title',
        messageKey: 'notif_daily_profit_received_msg',
        parameters: {'amount': '\$15.00', 'plan': 'VIP Plan'},
      );

      final title = ContentLocalizationService.notificationTitle(n);
      final msg = ContentLocalizationService.notificationMessage(n);

      expect(title, 'Daily Profits Received ✅');
      expect(msg, 'A profit of \$15.00 from (VIP Plan) has been credited successfully.');
    });

    test('resolves notification with keys in Arabic', () {
      Get.updateLocale(const Locale('ar', 'SA'));

      final n = NotificationModel(
        id: 'n1',
        title: 'Daily Profits',
        message: 'Profit received',
        titleKey: 'notif_daily_profit_received_title',
        messageKey: 'notif_daily_profit_received_msg',
        parameters: {'amount': '\$15.00', 'plan': 'باقة كاسبي'},
      );

      final title = ContentLocalizationService.notificationTitle(n);
      final msg = ContentLocalizationService.notificationMessage(n);

      expect(title, 'أرباح استثمار جديدة 💰');
      expect(msg, 'تم إضافة ربح بقيمة \$15.00 من استثمار (باقة كاسبي) بنجاح.');
    });

    test('falls back to regex/resolve when titleKey is null', () {
      Get.updateLocale(const Locale('en', 'US'));

      final n = NotificationModel(
        id: 'n2',
        title: 'أرباح استثمار جديدة 💰',
        message: 'تمت إضافة أرباح بقيمة \$25 إلى محفظتك.',
      );

      final title = ContentLocalizationService.notificationTitle(n);
      final msg = ContentLocalizationService.notificationMessage(n);

      expect(title, 'New Investment Profit 💰');
      expect(msg, '\$25 profit has been added to your wallet.');
    });
  });
}
