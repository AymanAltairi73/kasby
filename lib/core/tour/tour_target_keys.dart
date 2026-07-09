import 'package:flutter/material.dart';

/// GlobalKeys and scroll controllers for coach-mark tour targets.
/// Made mutable to support recreation on shell initialization, preventing
/// duplicate GlobalKeys and ScrollController-attached-to-multiple-scroll-views
/// errors during route transitions.
class TourTargetKeys {
  TourTargetKeys._();

  // ── Home ──────────────────────────────────────────────────────────────────
  static GlobalKey welcome = GlobalKey();
  static GlobalKey wallet = GlobalKey();
  static GlobalKey kspRewards = GlobalKey();
  static GlobalKey quickActions = GlobalKey();
  static GlobalKey marketplace = GlobalKey();
  static GlobalKey notifications = GlobalKey();
  static GlobalKey transactions = GlobalKey();
  static GlobalKey referralSummary = GlobalKey();
  static GlobalKey investNav = GlobalKey();
  static GlobalKey profileNav = GlobalKey();
  static ScrollController homeScroll = ScrollController();

  // ── Investments ───────────────────────────────────────────────────────────
  static GlobalKey investPlansList = GlobalKey();
  static GlobalKey investActiveTab = GlobalKey();
  static GlobalKey investClaimRewards = GlobalKey();

  // ── Wallet ────────────────────────────────────────────────────────────────
  static GlobalKey walletBalance = GlobalKey();
  static GlobalKey walletDeposit = GlobalKey();
  static GlobalKey walletWithdraw = GlobalKey();
  static GlobalKey walletTransfer = GlobalKey();
  static GlobalKey walletHistory = GlobalKey();

  // ── Marketplace ───────────────────────────────────────────────────────────
  static GlobalKey marketplaceCategories = GlobalKey();
  static GlobalKey marketplaceSearch = GlobalKey();
  static GlobalKey marketplaceCart = GlobalKey();

  // ── Social ────────────────────────────────────────────────────────────────
  static GlobalKey socialDashboard = GlobalKey();
  static GlobalKey socialRequests = GlobalKey();
  static GlobalKey socialFriends = GlobalKey();
  static GlobalKey socialInvite = GlobalKey();

  // ── QR ────────────────────────────────────────────────────────────────────
  static GlobalKey qrScanner = GlobalKey();
  static GlobalKey qrReceive = GlobalKey();
  static GlobalKey qrShare = GlobalKey();

  // ── Lucky wheel ───────────────────────────────────────────────────────────
  static GlobalKey spinWheel = GlobalKey();
  static GlobalKey spinFreeSpin = GlobalKey();
  static GlobalKey spinBuy = GlobalKey();
  static GlobalKey spinHistory = GlobalKey();

  // ── Referral ──────────────────────────────────────────────────────────────
  static GlobalKey referralCode = GlobalKey();
  static GlobalKey referralLink = GlobalKey();
  static GlobalKey referralTeam = GlobalKey();
  static GlobalKey referralRewards = GlobalKey();
  static GlobalKey referralCommission = GlobalKey();

  // ── Profile / security ────────────────────────────────────────────────────
  static GlobalKey profileKyc = GlobalKey();
  static GlobalKey profileSecurity = GlobalKey();
  static GlobalKey profilePin = GlobalKey();
  static GlobalKey profileLanguage = GlobalKey();

  /// Recreates all GlobalKeys and disposes/recreates the ScrollController.
  /// Should be called during MainShellView initialization to prevent
  /// duplicate keys and controllers in the widget tree during transition animation periods.
  static void recreateKeys() {
    try {
      homeScroll.dispose();
    } catch (_) {}

    welcome = GlobalKey();
    wallet = GlobalKey();
    kspRewards = GlobalKey();
    quickActions = GlobalKey();
    marketplace = GlobalKey();
    notifications = GlobalKey();
    transactions = GlobalKey();
    referralSummary = GlobalKey();
    investNav = GlobalKey();
    profileNav = GlobalKey();
    homeScroll = ScrollController();

    investPlansList = GlobalKey();
    investActiveTab = GlobalKey();
    investClaimRewards = GlobalKey();

    walletBalance = GlobalKey();
    walletDeposit = GlobalKey();
    walletWithdraw = GlobalKey();
    walletTransfer = GlobalKey();
    walletHistory = GlobalKey();

    marketplaceCategories = GlobalKey();
    marketplaceSearch = GlobalKey();
    marketplaceCart = GlobalKey();

    socialDashboard = GlobalKey();
    socialRequests = GlobalKey();
    socialFriends = GlobalKey();
    socialInvite = GlobalKey();

    qrScanner = GlobalKey();
    qrReceive = GlobalKey();
    qrShare = GlobalKey();

    spinWheel = GlobalKey();
    spinFreeSpin = GlobalKey();
    spinBuy = GlobalKey();
    spinHistory = GlobalKey();

    referralCode = GlobalKey();
    referralLink = GlobalKey();
    referralTeam = GlobalKey();
    referralRewards = GlobalKey();
    referralCommission = GlobalKey();

    profileKyc = GlobalKey();
    profileSecurity = GlobalKey();
    profilePin = GlobalKey();
    profileLanguage = GlobalKey();
  }
}
