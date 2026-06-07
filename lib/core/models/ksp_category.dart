import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';

enum KspCategoryType {
  dailyProfit,
  investmentProfit,
  referralReward,
  spinReward,
  checkInReward,
  transferIn,
  transferOut,
  bonusReward,
  claimedReward,
  unknown;

  String get translationKey {
    switch (this) {
      case KspCategoryType.dailyProfit:
        return 'ksp_cat_daily_profit';
      case KspCategoryType.investmentProfit:
        return 'ksp_cat_investment_profit';
      case KspCategoryType.referralReward:
        return 'ksp_cat_referral_reward';
      case KspCategoryType.spinReward:
        return 'ksp_cat_spin_reward';
      case KspCategoryType.checkInReward:
        return 'ksp_cat_checkin_reward';
      case KspCategoryType.transferIn:
        return 'ksp_cat_transfer_in';
      case KspCategoryType.transferOut:
        return 'ksp_cat_transfer_out';
      case KspCategoryType.bonusReward:
        return 'ksp_cat_bonus_reward';
      case KspCategoryType.claimedReward:
        return 'ksp_cat_claimed_reward';
      case KspCategoryType.unknown:
        return 'ksp_cat_unknown';
    }
  }

  String get label => translationKey.tr;

  IconData get icon {
    switch (this) {
      case KspCategoryType.dailyProfit:
        return Icons.trending_up_rounded;
      case KspCategoryType.investmentProfit:
        return Icons.account_balance_wallet_rounded;
      case KspCategoryType.referralReward:
        return Icons.people_alt_rounded;
      case KspCategoryType.spinReward:
        return Icons.casino_rounded;
      case KspCategoryType.checkInReward:
        return Icons.calendar_today_rounded;
      case KspCategoryType.transferIn:
        return Icons.arrow_downward_rounded;
      case KspCategoryType.transferOut:
        return Icons.arrow_upward_rounded;
      case KspCategoryType.bonusReward:
        return Icons.card_giftcard_rounded;
      case KspCategoryType.claimedReward:
        return Icons.check_circle_outline_rounded;
      case KspCategoryType.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color get color {
    switch (this) {
      case KspCategoryType.dailyProfit:
      case KspCategoryType.investmentProfit:
      case KspCategoryType.transferIn:
      case KspCategoryType.claimedReward:
        return AppColors.softGreen;
      case KspCategoryType.transferOut:
        return AppColors.error;
      case KspCategoryType.referralReward:
      case KspCategoryType.spinReward:
      case KspCategoryType.checkInReward:
      case KspCategoryType.bonusReward:
        return AppColors.darkGold;
      case KspCategoryType.unknown:
        return AppColors.textSecondary;
    }
  }

  static KspCategoryType fromDescription(String? description, String? type) {
    if (description == null) {
      if (type == 'earn') return KspCategoryType.bonusReward;
      if (type == 'spend') return KspCategoryType.transferOut;
      if (type == 'transfer_in') return KspCategoryType.transferIn;
      if (type == 'transfer_out') return KspCategoryType.transferOut;
      return KspCategoryType.unknown;
    }

    final desc = description.toLowerCase();
    
    // Check type/transfers
    if (type == 'transfer_in' || desc.contains('نقاط محوّلة من') || desc.contains('transferred from') || desc.contains('received points')) {
      return KspCategoryType.transferIn;
    }
    if (type == 'transfer_out' || desc.contains('تحويل نقاط إلى') || desc.contains('transfer to') || desc.contains('sent points')) {
      return KspCategoryType.transferOut;
    }
    
    // Check daily check-in
    if (desc.contains('daily check-in') || desc.contains('تسجيل الدخول اليومي') || desc.contains('checkin') || desc.contains('check-in')) {
      return KspCategoryType.checkInReward;
    }
    
    // Check spin wheel
    if (desc.contains('spin') || desc.contains('عجلة الحظ') || desc.contains('spin')) {
      return KspCategoryType.spinReward;
    }
    
    // Check referral
    if (desc.contains('referral') || desc.contains('إحالة') || desc.contains('invite') || desc.contains('friend')) {
      return KspCategoryType.referralReward;
    }
    
    // Check investment profit
    if (desc.contains('claimed released rewards') || desc.contains('أرباح الاستثمار') || desc.contains('released rewards') || desc.contains('investment')) {
      return KspCategoryType.investmentProfit;
    }
    
    // Check daily profit
    if (desc.contains('daily profit') || desc.contains('الربح اليومي') || desc.contains('أرباح يومية')) {
      return KspCategoryType.dailyProfit;
    }
    
    // Check claimed reward
    if (desc.contains('claimed') || desc.contains('تم استلام') || desc.contains('claim')) {
      return KspCategoryType.claimedReward;
    }

    if (type == 'earn') {
      return KspCategoryType.bonusReward;
    }
    if (type == 'spend') {
      return KspCategoryType.transferOut;
    }
    
    return KspCategoryType.unknown;
  }
}
