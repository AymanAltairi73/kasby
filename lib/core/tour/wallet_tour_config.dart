import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'tour_ids.dart';
import 'tour_step.dart';
import 'tour_target_keys.dart';

class WalletTourConfig {
  WalletTourConfig._();

  static List<TourStepDefinition> get steps => [
        TourStepDefinition(
          id: 'balance',
          tourId: TourId.wallet,
          targetKey: TourTargetKeys.walletBalance,
          titleKey: 'tour_wallet_balance_title',
          descriptionKey: 'tour_wallet_balance_desc',
          preferredAlign: ContentAlign.bottom,
        ),
        TourStepDefinition(
          id: 'deposit',
          tourId: TourId.wallet,
          targetKey: TourTargetKeys.walletDeposit,
          titleKey: 'tour_wallet_deposit_title',
          descriptionKey: 'tour_wallet_deposit_desc',
          preferredAlign: ContentAlign.bottom,
        ),
        TourStepDefinition(
          id: 'withdraw',
          tourId: TourId.wallet,
          targetKey: TourTargetKeys.walletWithdraw,
          titleKey: 'tour_wallet_withdraw_title',
          descriptionKey: 'tour_wallet_withdraw_desc',
          preferredAlign: ContentAlign.bottom,
        ),
        TourStepDefinition(
          id: 'transfer',
          tourId: TourId.wallet,
          targetKey: TourTargetKeys.walletTransfer,
          titleKey: 'tour_wallet_transfer_title',
          descriptionKey: 'tour_wallet_transfer_desc',
          preferredAlign: ContentAlign.top,
        ),
        TourStepDefinition(
          id: 'history',
          tourId: TourId.wallet,
          targetKey: TourTargetKeys.walletHistory,
          titleKey: 'tour_wallet_history_title',
          descriptionKey: 'tour_wallet_history_desc',
          preferredAlign: ContentAlign.top,
        ),
      ];
}
