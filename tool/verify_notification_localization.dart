import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/models/profile_model.dart';
import 'package:kasby/core/models/notification_model.dart';
import 'package:kasby/core/localization/content_localization_service.dart';
import 'package:kasby/core/localization/kasby_translations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Get.addTranslations(KasbyTranslations().keys);

  print('=== STARTING NOTIFICATION LOCALIZATION VERIFICATION ===\n');

  // 1. ProfileModel tests
  print('[1/4] Testing ProfileModel...');
  final pDefault = ProfileModel.fromJson({
    'id': 'u1',
    'full_name': 'Test User',
    'role': 'user',
  });
  assert(pDefault.language == 'ar', 'Default language should be ar');
  print('  ✓ ProfileModel defaults language to ar');

  final pEn = ProfileModel.fromJson({
    'id': 'u1',
    'full_name': 'Test User',
    'role': 'user',
    'language': 'en',
  });
  assert(pEn.language == 'en', 'Language should be en');
  assert(pEn.toJson()['language'] == 'en', 'toJson should contain language');
  print('  ✓ ProfileModel parses and serializes language');

  final pCopy = pDefault.copyWith(language: 'en');
  assert(pCopy.language == 'en', 'copyWith should update language');
  print('  ✓ ProfileModel copyWith works');

  // 2. NotificationModel tests
  print('\n[2/4] Testing NotificationModel...');
  final notifJson = {
    'id': 'n1',
    'title': 'أرباح جديدة',
    'message': 'تم إضافة ربح بقيمة \$10 من استثمار (الذهب) بنجاح',
    'title_key': 'notif_daily_profit_received_title',
    'message_key': 'notif_daily_profit_received_msg',
    'parameters': {'amount': '\$10', 'plan': 'Gold Plan'},
  };
  final n1 = NotificationModel.fromJson(notifJson);
  assert(n1.titleKey == 'notif_daily_profit_received_title', 'titleKey parsed');
  assert(n1.messageKey == 'notif_daily_profit_received_msg', 'messageKey parsed');
  assert(n1.parameters?['amount'] == '\$10', 'parameter amount parsed');
  assert(n1.parameters?['plan'] == 'Gold Plan', 'parameter plan parsed');
  print('  ✓ NotificationModel parses title_key, message_key, parameters Map');

  final notifJsonStr = {
    'id': 'n2',
    'title': 'Test',
    'message': 'Test Msg',
    'title_key': 'notif_ksp_redeem_success_title',
    'message_key': 'notif_ksp_redeem_success_msg',
    'parameters': jsonEncode({'points': '100', 'amount': '\$5'}),
  };
  final n2 = NotificationModel.fromJson(notifJsonStr);
  assert(n2.parameters?['points'] == '100', 'parameters string parsed points');
  assert(n2.parameters?['amount'] == '\$5', 'parameters string parsed amount');
  print('  ✓ NotificationModel parses parameters from JSON string');

  // 3. ContentLocalizationService English Resolution
  print('\n[3/4] Testing ContentLocalizationService (English)...');
  Get.updateLocale(const Locale('en', 'US'));

  final enNotif = NotificationModel(
    id: 'n1',
    title: 'أرباح يومية',
    message: 'تم إضافة ربح',
    titleKey: 'notif_daily_profit_received_title',
    messageKey: 'notif_daily_profit_received_msg',
    parameters: {'amount': '\$15.00', 'plan': 'VIP Plan'},
  );
  final enTitle = ContentLocalizationService.notificationTitle(enNotif);
  final enMsg = ContentLocalizationService.notificationMessage(enNotif);
  print('  Resolved English Title: $enTitle');
  print('  Resolved English Msg:   $enMsg');
  assert(enTitle == 'Daily Profits Received ✅', 'Title should be English');
  assert(
    enMsg == 'A profit of \$15.00 from (VIP Plan) has been credited successfully.',
    'Message should be English with params',
  );
  print('  ✓ Key+params resolves correctly into English');

  // 4. ContentLocalizationService Arabic Resolution
  print('\n[4/4] Testing ContentLocalizationService (Arabic)...');
  Get.updateLocale(const Locale('ar', 'SA'));

  final arNotif = NotificationModel(
    id: 'n1',
    title: 'Daily Profits',
    message: 'Profit received',
    titleKey: 'notif_daily_profit_received_title',
    messageKey: 'notif_daily_profit_received_msg',
    parameters: {'amount': '\$15.00', 'plan': 'باقة كاسبي'},
  );
  final arTitle = ContentLocalizationService.notificationTitle(arNotif);
  final arMsg = ContentLocalizationService.notificationMessage(arNotif);
  print('  Resolved Arabic Title: $arTitle');
  print('  Resolved Arabic Msg:   $arMsg');
  assert(arTitle == 'أرباح استثمار جديدة 💰', 'Title should be Arabic');
  assert(
    arMsg == 'تم إضافة ربح بقيمة \$15.00 من استثمار (باقة كاسبي) بنجاح.',
    'Message should be Arabic with params',
  );
  print('  ✓ Key+params resolves correctly into Arabic');

  // 5. Fallback for legacy notifications without keys
  print('\n[5/5] Testing legacy notification regex fallback...');
  Get.updateLocale(const Locale('en', 'US'));
  final legacyNotif = NotificationModel(
    id: 'legacy_1',
    title: 'أرباح استثمار جديدة 💰',
    message: 'تمت إضافة أرباح بقيمة \$25 إلى محفظتك.',
  );
  final legacyTitle = ContentLocalizationService.notificationTitle(legacyNotif);
  final legacyMsg = ContentLocalizationService.notificationMessage(legacyNotif);
  print('  Legacy Title (AR->EN): $legacyTitle');
  print('  Legacy Msg (AR->EN):   $legacyMsg');
  assert(legacyTitle == 'New Investment Profit 💰', 'Legacy title resolved');
  assert(legacyMsg == '\$25 profit has been added to your wallet.', 'Legacy msg resolved');
  print('  ✓ Legacy fallback resolves correctly');

  print('\n🎉 ALL 5 VERIFICATION CHECKS PASSED SUCCESSFULLY!');
}
