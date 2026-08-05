import 'package:kasby/core/localization/content_localization_service.dart';
import 'package:kasby/core/models/notification_model.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/models/earnings_analytics_model.dart';

extension NotificationModelLocalization on NotificationModel {
  String get localizedTitle =>
      ContentLocalizationService.notificationTitle(this);

  String get localizedMessage =>
      ContentLocalizationService.notificationMessage(this);
}

extension TransactionModelLocalization on TransactionModel {
  String get localizedDescription =>
      ContentLocalizationService.transactionDescription(this);

  String get localizedTypeLabel =>
      ContentLocalizationService.transactionTypeLabel(type);

  String get localizedStatusLabel =>
      ContentLocalizationService.transactionStatusLabel(status);
}

extension TimelineItemLocalization on TimelineItem {
  String get localizedDescription =>
      ContentLocalizationService.resolve(description, context: 'timeline_item');
}
