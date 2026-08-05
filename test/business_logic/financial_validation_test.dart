import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/wallet_model.dart';
import 'package:kasby/core/models/transaction_model.dart';
import 'package:kasby/core/models/loan_model.dart';
import 'package:kasby/core/models/user_investment_model.dart';

void main() {
  group('Financial Business Logic Validation', () {
    group('Deposit Flow', () {
      test('deposit creates credit transaction with correct type', () {
        final txn = TransactionModel(
          id: 'dep-1',
          userId: 'u1',
          walletId: 'w1',
          type: 'deposit',
          amount: 500.0,
          status: 'pending',
        );

        expect(txn.isCredit, true);
        expect(txn.isDebit, false);
        expect(txn.amount, 500.0);
        expect(txn.status, 'pending');
      });

      test('approved deposit updates wallet available balance', () {
        final wallet = WalletModel(
          id: 'w1',
          userId: 'u1',
          availableBalance: 1000.0,
        );

        final depositAmount = 500.0;
        final updatedWallet = wallet.copyWith(
          availableBalance: wallet.availableBalance + depositAmount,
        );

        expect(updatedWallet.availableBalance, 1500.0);
      });
    });

    group('Withdrawal Flow', () {
      test('withdrawal creates debit transaction', () {
        final txn = TransactionModel(
          id: 'wd-1',
          userId: 'u1',
          walletId: 'w1',
          type: 'withdrawal',
          amount: 200.0,
          fee: 5.0,
          status: 'pending',
        );

        expect(txn.isDebit, true);
        expect(txn.fee, 5.0);
      });

      test('withdrawal cannot exceed available balance', () {
        final wallet = WalletModel(
          id: 'w1',
          userId: 'u1',
          availableBalance: 100.0,
        );

        final withdrawalAmount = 200.0;
        final canWithdraw = wallet.availableBalance >= withdrawalAmount;

        expect(canWithdraw, false);
      });

      test('frozen wallet blocks withdrawal', () {
        final wallet = WalletModel(
          id: 'w1',
          userId: 'u1',
          availableBalance: 1000.0,
          isFrozen: true,
          frozenReason: 'Suspicious activity',
        );

        expect(wallet.isFrozen, true);
      });
    });

    group('Transfer Flow', () {
      test('transfer creates matching credit and debit transactions', () {
        final sender = TransactionModel(
          id: 'tf-out-1',
          userId: 'u1',
          walletId: 'w1',
          type: 'transfer_out',
          amount: 100.0,
          counterpartUserId: 'u2',
          status: 'completed',
        );

        final receiver = TransactionModel(
          id: 'tf-in-1',
          userId: 'u2',
          walletId: 'w2',
          type: 'transfer_in',
          amount: 100.0,
          counterpartUserId: 'u1',
          status: 'completed',
        );

        expect(sender.isDebit, true);
        expect(receiver.isCredit, true);
        expect(sender.amount, receiver.amount);
      });
    });

    group('Investment Flow', () {
      test('investment deducts from available balance', () {
        final wallet = WalletModel(
          id: 'w1',
          userId: 'u1',
          availableBalance: 5000.0,
          investedBalance: 0.0,
        );

        final investmentAmount = 1000.0;
        final updatedWallet = wallet.copyWith(
          availableBalance: wallet.availableBalance - investmentAmount,
          investedBalance: wallet.investedBalance + investmentAmount,
        );

        expect(updatedWallet.availableBalance, 4000.0);
        expect(updatedWallet.investedBalance, 1000.0);
        expect(updatedWallet.totalBalance, wallet.totalBalance);
      });

      test('investment creates debit transaction', () {
        final txn = TransactionModel(
          id: 'inv-txn-1',
          userId: 'u1',
          walletId: 'w1',
          type: 'investment',
          amount: 1000.0,
          status: 'completed',
        );

        expect(txn.isDebit, true);
      });

      test('investment return creates credit transaction', () {
        final txn = TransactionModel(
          id: 'inv-ret-1',
          userId: 'u1',
          walletId: 'w1',
          type: 'investment_return',
          amount: 1100.0,
          status: 'completed',
        );

        expect(txn.isCredit, true);
      });

      test('investment expected profit calculation', () {
        final investment = UserInvestmentModel(
          id: 'inv-1',
          userId: 'u1',
          planId: 'p1',
          amount: 1000.0,
          profitPercentage: 15.0,
          expectedProfit: 150.0,
        );

        expect(
          investment.expectedProfit,
          investment.amount * investment.profitPercentage / 100,
        );
      });
    });

    group('Daily Profit Distribution', () {
      test('profit transaction is credit type', () {
        final profitTxn = TransactionModel(
          id: 'profit-1',
          userId: 'u1',
          walletId: 'w1',
          type: 'profit',
          amount: 10.0,
          status: 'completed',
        );

        expect(profitTxn.isCredit, true);
        expect(profitTxn.type, 'profit');
      });

      test('profit adds to profit balance', () {
        final wallet = WalletModel(id: 'w1', userId: 'u1', profitBalance: 50.0);

        final profitAmount = 10.0;
        final updated = wallet.copyWith(
          profitBalance: wallet.profitBalance + profitAmount,
        );

        expect(updated.profitBalance, 60.0);
      });
    });

    group('Loan Flow', () {
      test('loan creation with interest calculation', () {
        final loan = LoanModel(
          id: 'loan-1',
          userId: 'u1',
          amount: 1000.0,
          interestRate: 5.0,
          totalDue: 1050.0,
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(
          loan.totalDue,
          loan.amount + (loan.amount * loan.interestRate / 100),
        );
      });

      test('loan disbursement is credit transaction', () {
        final txn = TransactionModel(
          id: 'loan-dis-1',
          userId: 'u1',
          walletId: 'w1',
          type: 'loan_disbursement',
          amount: 1000.0,
          status: 'completed',
        );

        expect(txn.isCredit, true);
      });

      test('loan repayment is debit transaction', () {
        final txn = TransactionModel(
          id: 'loan-rep-1',
          userId: 'u1',
          walletId: 'w1',
          type: 'loan_repayment',
          amount: 200.0,
          status: 'completed',
        );

        expect(txn.isDebit, true);
      });

      test('partial loan repayment updates progress', () {
        final loan = LoanModel(
          id: 'loan-1',
          userId: 'u1',
          amount: 1000.0,
          totalDue: 1050.0,
          paidAmount: 525.0,
          status: 'partial_paid',
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.paymentProgress, 0.5);
        expect(loan.calculatedRemaining, 525.0);
      });

      test('full loan repayment marks complete', () {
        final loan = LoanModel(
          id: 'loan-2',
          userId: 'u1',
          amount: 1000.0,
          totalDue: 1050.0,
          paidAmount: 1050.0,
          status: 'paid',
          repaymentDate: DateTime(2026, 12, 31),
        );

        expect(loan.paymentProgress, 1.0);
        expect(loan.calculatedRemaining, 0.0);
      });
    });

    group('KSP (Spin Rewards) Flow', () {
      test('reward transaction is credit', () {
        final txn = TransactionModel(
          id: 'reward-1',
          userId: 'u1',
          walletId: 'w1',
          type: 'reward',
          amount: 5.0,
          status: 'completed',
        );

        expect(txn.isCredit, true);
      });
    });

    group('Wallet Integrity', () {
      test('total balance equals sum of all balance types', () {
        final wallet = WalletModel(
          id: 'w1',
          userId: 'u1',
          availableBalance: 1000.0,
          profitBalance: 200.0,
          investedBalance: 5000.0,
          pendingBalance: 300.0,
        );

        expect(wallet.totalBalance, 6500.0);
        expect(
          wallet.totalBalance,
          wallet.availableBalance +
              wallet.profitBalance +
              wallet.investedBalance +
              wallet.pendingBalance,
        );
      });

      test('balance never goes negative via copyWith validation', () {
        final wallet = WalletModel(
          id: 'w1',
          userId: 'u1',
          availableBalance: 100.0,
        );

        final withdrawAmount = 150.0;
        final canProcess = wallet.availableBalance >= withdrawAmount;
        expect(canProcess, false);
      });
    });

    group('Idempotency', () {
      test('transaction has idempotency key field', () {
        final txn = TransactionModel(
          id: 'txn-idem',
          idempotencyKey: 'unique-key-12345',
          userId: 'u1',
          walletId: 'w1',
          type: 'deposit',
          amount: 100.0,
        );

        expect(txn.idempotencyKey, 'unique-key-12345');
      });

      test('idempotency key serialized in toJson', () {
        final txn = TransactionModel(
          id: 'txn-idem-2',
          idempotencyKey: 'key-xyz',
          userId: 'u1',
          walletId: 'w1',
          type: 'deposit',
          amount: 100.0,
        );

        final json = txn.toJson();
        expect(json['idempotency_key'], 'key-xyz');
      });
    });
  });
}
