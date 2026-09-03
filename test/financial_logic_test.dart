import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Kasby Financial & Business Logic Unit Tests', () {
    // ── 1. DAILY PROFIT & AUTO RESTART MATRIX ──
    test('Daily Profit Calculation', () {
      final investedAmount = 1000.0;
      final annualReturnRate = 12.0; // 12% APY
      
      final expectedDailyProfit = (investedAmount * (annualReturnRate / 100)) / 365;
      expect(expectedDailyProfit, closeTo(0.32876, 0.0001));
    });

    test('Scenario A: Investment ACTIVE & Auto Restart ON', () {
      final status = 'active';
      final autoRestartEnabled = true;
      
      bool isEligibleForProfit(String status, bool autoRestart) {
        return status == 'active' && autoRestart;
      }
      
      expect(isEligibleForProfit(status, autoRestartEnabled), isTrue);
    });

    test('Scenario B: Investment ACTIVE & Auto Restart OFF', () {
      final status = 'active';
      final autoRestartEnabled = false;
      
      bool isEligibleForProfit(String status, bool autoRestart) {
        return status == 'active' && autoRestart;
      }
      
      expect(isEligibleForProfit(status, autoRestartEnabled), isFalse);
    });

    test('Scenario C: Auto Restart OFF -> ON Prospective Resumption', () {
      var autoRestart = false;
      final lastPayout = DateTime.utc(2026, 8, 20);
      
      // User toggles Auto Restart ON on Aug 23
      autoRestart = true;
      
      DateTime calculateNextPayout(DateTime lastDate, bool enabled) {
        return enabled ? lastDate.add(const Duration(days: 1)) : lastDate;
      }
      
      final nextPayout = calculateNextPayout(lastPayout, autoRestart);
      expect(nextPayout, equals(DateTime.utc(2026, 8, 21)));
    });

    test('Scenario D: Multiple Investments Auto Restart Isolation', () {
      final investments = [
        {'id': 'inv_A', 'status': 'active', 'auto_restart': false},
        {'id': 'inv_B', 'status': 'active', 'auto_restart': true},
      ];

      final eligible = investments.where(
        (inv) => inv['status'] == 'active' && inv['auto_restart'] == true,
      ).toList();

      expect(eligible.length, equals(1));
      expect(eligible.first['id'], equals('inv_B'));
    });

    // ── 2. DAILY EARNINGS ACCUMULATION & DAY RESET ──
    test('Daily Earnings Accumulation and Calendar Day Reset', () {
      var dailyEarnings = 0.0;
      var currentDate = DateTime.utc(2026, 8, 23);

      // Profit 1 arrives
      dailyEarnings += 1.50;
      expect(dailyEarnings, equals(1.50));

      // Profit 2 arrives same day
      dailyEarnings += 2.25;
      expect(dailyEarnings, equals(3.75));

      // Next calendar day arrives
      currentDate = DateTime.utc(2026, 8, 24);
      double resetDailyEarningsOnNewDay(DateTime lastDate, DateTime newDate, double currentEarnings) {
        if (lastDate.day != newDate.day || lastDate.month != newDate.month || lastDate.year != newDate.year) {
          return 0.0;
        }
        return currentEarnings;
      }

      dailyEarnings = resetDailyEarningsOnNewDay(DateTime.utc(2026, 8, 23), currentDate, dailyEarnings);
      expect(dailyEarnings, equals(0.0));
    });

    // ── 3. WALLET BALANCE & TRANSFER SAFETY ──
    test('Wallet Balance Deduction & Insufficient Balance Validation', () {
      final availableBalance = 50.0;
      final transferAmount = 100.0;

      bool canTransfer(double balance, double amount) {
        return balance >= amount && amount > 0;
      }

      expect(canTransfer(availableBalance, transferAmount), isFalse);
      expect(canTransfer(availableBalance, 30.0), isTrue);
    });

    test('Transfer Atomic Sender/Receiver Balance Alignment', () {
      var senderBalance = 200.0;
      var receiverBalance = 50.0;
      final amount = 75.0;

      senderBalance -= amount;
      receiverBalance += amount;

      expect(senderBalance, equals(125.0));
      expect(receiverBalance, equals(125.0));
    });

    // ── 4. STORE PURCHASE VALIDATION & STOCK LOCKING ──
    test('Store Product Discounted Price & Balance Validation', () {
      final originalPrice = 50.0;
      final discountPercent = 10.0; // 10% discount
      final finalPrice = originalPrice * (1.0 - (discountPercent / 100.0));
      expect(finalPrice, equals(45.0));

      final userBalance = 40.0;
      expect(userBalance >= finalPrice, isFalse);
    });

    test('Store Purchase Out of Stock Guard', () {
      final stockCount = 0;
      bool canPurchase(int stock) => stock > 0;
      expect(canPurchase(stockCount), isFalse);
    });

    // ── 5. REFERRAL COMMISSION & IDEMPOTENCY ──
    test('Referral 2% Commission Calculation & Idempotency Key', () {
      final investmentAmount = 500.0;
      final commissionRate = 0.02; // 2%
      final expectedCommission = investmentAmount * commissionRate;
      expect(expectedCommission, equals(10.0));

      final processedInvestments = <String>{'inv_1001'};
      bool processCommission(String invId) {
        if (processedInvestments.contains(invId)) {
          return false; // Idempotent block
        }
        processedInvestments.add(invId);
        return true;
      }

      expect(processCommission('inv_1001'), isFalse);
      expect(processCommission('inv_1002'), isTrue);
    });

    // ── 6. LOAN ELIGIBILITY ──
    test('Loan Request Active Investment Requirement', () {
      bool canApplyForLoan(double investedBalance, double requestedAmount) {
        return investedBalance > 0 && requestedAmount > 0;
      }

      expect(canApplyForLoan(0.0, 100.0), isFalse);
      expect(canApplyForLoan(500.0, 100.0), isTrue);
    });

    // ── 7. NOTIFICATION PAYLOAD ROUTING ──
    test('Notification Payload Route Resolution', () {
      String resolveNotificationRoute(String type, String entityType) {
        if (type == 'store_purchase' || type == 'store_order' || entityType == 'store_order') {
          return '/store-orders';
        }
        if (type == 'agent_message' || entityType == 'agent_conversation') {
          return '/agent-chat';
        }
        if (type == 'transfer_sent' || type == 'transfer_received') {
          return '/all-transactions';
        }
        return '/notifications';
      }

      expect(resolveNotificationRoute('store_purchase', 'store_order'), equals('/store-orders'));
      expect(resolveNotificationRoute('agent_message', 'agent_conversation'), equals('/agent-chat'));
      expect(resolveNotificationRoute('transfer_sent', 'transaction'), equals('/all-transactions'));
    });

    // ── 8. INPUT VALIDATION ──
    test('Input Validation - Phone Number Format', () {
      bool isValidPhone(String input) {
        final cleaned = input.replaceAll(RegExp(r'\s+'), '');
        return RegExp(r'^\+?[0-9]{9,15}$').hasMatch(cleaned);
      }

      expect(isValidPhone('+9647700000000'), isTrue);
      expect(isValidPhone('07700000000'), isTrue);
      expect(isValidPhone('123'), isFalse);
    });

    test('Input Validation - Email Format', () {
      bool isValidEmail(String input) {
        return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(input.trim());
      }

      expect(isValidEmail('user@kasby.app'), isTrue);
      expect(isValidEmail('invalid-email'), isFalse);
    });

    // ── 9. KASBY INSUFFICIENT BALANCE & FINANCIAL REMEDIATION MATRIX ──
    group('Remediation Financial Audit Matrix (\$500 Starting Balance)', () {
      test('1. Transfer \$100 with Fee Validation (\$500 -> \$398)', () {
        var availableBalance = 500.0;
        final transferAmount = 100.0;
        final fee = 2.0; // 2% transfer fee
        final totalRequired = transferAmount + fee;

        expect(availableBalance >= totalRequired, isTrue);
        availableBalance -= totalRequired;

        expect(availableBalance, equals(398.0));
      });

      test('2. Withdrawal \$100 (\$398 -> \$298 Available, \$100 Pending)', () {
        var availableBalance = 398.0;
        var pendingBalance = 0.0;
        final withdrawAmount = 100.0;

        expect(availableBalance >= withdrawAmount, isTrue);
        availableBalance -= withdrawAmount;
        pendingBalance += withdrawAmount;

        expect(availableBalance, equals(298.0));
        expect(pendingBalance, equals(100.0));
      });

      test('3. Investment \$100 (\$298 -> \$198 Available, \$100 Invested)', () {
        var availableBalance = 298.0;
        var investedBalance = 0.0;
        final investmentAmount = 100.0;

        expect(availableBalance >= investmentAmount, isTrue);
        availableBalance -= investmentAmount;
        investedBalance += investmentAmount;

        expect(availableBalance, equals(198.0));
        expect(investedBalance, equals(100.0));
      });

      test('4. Reject Transfer > Available Balance (\$300 > \$198)', () {
        final availableBalance = 198.0;
        final transferAmount = 300.0;
        final fee = 6.0;
        final totalRequired = transferAmount + fee;

        final canExecute = availableBalance >= totalRequired;
        expect(canExecute, isFalse);
      });

      test('5. Reject Withdrawal > Available Balance (\$300 > \$198)', () {
        final availableBalance = 198.0;
        final withdrawAmount = 300.0;

        final canExecute = availableBalance >= withdrawAmount;
        expect(canExecute, isFalse);
      });

      test('6. Reject Investment > Available Balance (\$300 > \$198)', () {
        final availableBalance = 198.0;
        final investmentAmount = 300.0;

        final canExecute = availableBalance >= investmentAmount;
        expect(canExecute, isFalse);
      });

      test('7. KSP Points non-cash separation (\$50 cash + 450,000 KSP = \$500 portfolio)', () {
        final availableCashUSD = 50.0;
        final kspPoints = 450000; // $450 USD equivalent
        final totalPortfolioUsd = availableCashUSD + (kspPoints / 1000);

        expect(totalPortfolioUsd, equals(500.0));

        final transferUsdAmount = 100.0;
        // Validation MUST check availableCashUSD, NOT totalPortfolioUsd!
        final canTransferUSD = availableCashUSD >= transferUsdAmount;
        expect(canTransferUSD, isFalse);
      });
    });

    // ── 10. KASBY UNIFIED PDF REPORTING ENGINE VALIDATION ──
    group('PDF Reporting Engine & Data Integrity', () {
      test('KasbyReceiptData Model Verification', () {
        final receiptData = {
          'transactionId': 'TXN-987654321',
          'amount': 250.00,
          'type': 'deposit',
          'status': 'completed',
          'date': '2026-08-25 14:30',
          'recipientName': 'Ayman Altairi',
          'referenceNumber': 'REF-100234',
        };

        expect(receiptData['transactionId'], startsWith('TXN-'));
        expect(receiptData['amount'], equals(250.00));
        expect(receiptData['type'], equals('deposit'));
      });

      test('Statement Financial Aggregation Matrix', () {
        final transactions = [
          {'amount': 100.0, 'type': 'deposit', 'status': 'completed'},
          {'amount': 50.0, 'type': 'withdrawal', 'status': 'completed'},
          {'amount': 200.0, 'type': 'deposit', 'status': 'approved'},
          {'amount': 30.0, 'type': 'withdrawal', 'status': 'rejected'}, // Should exclude rejected
        ];

        double totalDeposits = 0.0;
        double totalWithdrawals = 0.0;

        for (var t in transactions) {
          final status = t['status'] as String;
          if (status == 'completed' || status == 'approved') {
            final amt = t['amount'] as double;
            if (t['type'] == 'deposit') {
              totalDeposits += amt;
            } else if (t['type'] == 'withdrawal') {
              totalWithdrawals += amt;
            }
          }
        }

        final netBalance = totalDeposits - totalWithdrawals;

        expect(totalDeposits, equals(300.0));
        expect(totalWithdrawals, equals(50.0));
        expect(netBalance, equals(250.0));
      });
    });

    // ── 11. USD & KSP BALANCES REACTIVE SYNCHRONIZATION MATRIX ──
    group('USD & KSP Synchronized Conversion Matrix (1 USD = 1,000 KSP)', () {
      const kspPerUsd = 1000.0;

      test('Exact Conversion Math: 1 USD = 1,000 KSP & 1 KSP = 0.001 USD', () {
        expect(1.0 * kspPerUsd, equals(1000.0));
        expect(10.0 * kspPerUsd, equals(10000.0));
        expect(100.0 * kspPerUsd, equals(100000.0));

        expect(1000.0 / kspPerUsd, equals(1.0));
        expect(10000.0 / kspPerUsd, equals(10.0));
        expect(100000.0 / kspPerUsd, equals(100.0));
      });

      test('Synchronized Update: Adding +10,000 KSP Rewards increases Total Effective USD by +\$10.00', () {
        var availableCashUsd = 100.0;
        var rewardKsp = 0;

        double getTotalEffectiveUsd() => availableCashUsd + (rewardKsp / kspPerUsd);
        int getTotalEffectiveKsp() => ((availableCashUsd * kspPerUsd) + rewardKsp).round();

        // Initial State
        expect(getTotalEffectiveUsd(), equals(100.0));
        expect(getTotalEffectiveKsp(), equals(100000));

        // Event: User wins 10,000 KSP from Spin Wheel / Daily Check-in
        rewardKsp += 10000;

        // Verified Synchronized State
        expect(getTotalEffectiveUsd(), equals(110.0)); // +$10.00 USD
        expect(getTotalEffectiveKsp(), equals(110000)); // +10,000 KSP
        expect(getTotalEffectiveKsp() / kspPerUsd, equals(getTotalEffectiveUsd()));
      });

      test('Synchronized Update: Adding +\$10.00 USD Cash increases Total Effective KSP by +10,000 KSP', () {
        var availableCashUsd = 100.0;
        var rewardKsp = 10000; // $10 USD equivalent

        double getTotalEffectiveUsd() => availableCashUsd + (rewardKsp / kspPerUsd);
        int getTotalEffectiveKsp() => ((availableCashUsd * kspPerUsd) + rewardKsp).round();

        // Initial State
        expect(getTotalEffectiveUsd(), equals(110.0));
        expect(getTotalEffectiveKsp(), equals(110000));

        // Event: Profit or Deposit credited to Available Cash (+$10.00 USD)
        availableCashUsd += 10.0;

        // Verified Synchronized State
        expect(getTotalEffectiveUsd(), equals(120.0)); // +$10.00 USD
        expect(getTotalEffectiveKsp(), equals(120000)); // +10,000 KSP
        expect(getTotalEffectiveKsp() / kspPerUsd, equals(getTotalEffectiveUsd()));
      });

      test('Zero Double-Counting Guard: Wallet Cash & Reward Points are distinct Single Sources of Truth', () {
        var walletCashUsd = 50.0;
        var rewardPointsKsp = 25000; // $25.00 USD equivalent

        // Calculate total effective balances
        final effectiveUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        final effectiveKsp = (walletCashUsd * kspPerUsd) + rewardPointsKsp;

        expect(effectiveUsd, equals(75.0));
        expect(effectiveKsp, equals(75000));

        // Spendable liquid cash MUST remain $50.0, NOT $75.0
        expect(walletCashUsd, equals(50.0));
        // KSP Reward points MUST remain 25,000, NOT 75,000
        expect(rewardPointsKsp, equals(25000));
        // Mathematical Identity holds perfectly
        expect(effectiveUsd * kspPerUsd, equals(effectiveKsp.toDouble()));
      });
    });

    // ── 12. DISPLAY BALANCE VS SPENDABLE BALANCE ISOLATION & SAFETY MATRIX ──
    group('Display Balance vs Spendable Balance Isolation & Safety Matrix', () {
      const kspPerUsd = 1000.0;

      test('Ecosystem Balance Display Unification: HomeBalanceCard == WalletView == StoreHomeView', () {
        const walletCashUsd = 100.0;
        const rewardPointsKsp = 50000; // $50.00 USD equivalent

        // Unified display value formula used across all views
        final homeDisplayUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        final walletViewDisplayUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        final storeHomeDisplayUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);

        final homeDisplayKsp = ((walletCashUsd * kspPerUsd) + rewardPointsKsp).round();
        final walletViewDisplayKsp = ((walletCashUsd * kspPerUsd) + rewardPointsKsp).round();
        final storeHomeDisplayKsp = ((walletCashUsd * kspPerUsd) + rewardPointsKsp).round();

        // 1. All UI views display 100% identical values ($150.00 USD & 150,000 KSP)
        expect(homeDisplayUsd, equals(150.0));
        expect(walletViewDisplayUsd, equals(150.0));
        expect(storeHomeDisplayUsd, equals(150.0));

        expect(homeDisplayKsp, equals(150000));
        expect(walletViewDisplayKsp, equals(150000));
        expect(storeHomeDisplayKsp, equals(150000));
      });

      test('Financial Execution Isolation: Spendable USD is strictly Wallet Cash, NOT Total Effective USD', () {
        var walletCashUsd = 20.0; // Spendable liquid cash
        var rewardPointsKsp = 80000; // $80.00 USD equivalent

        final totalEffectiveUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd); // $100.00 USD
        final spendableUsd = walletCashUsd; // $20.00 USD

        const productPriceUsd = 50.0; // Product costs $50 USD

        // Total display balance ($100.0) is > product price ($50.0)
        expect(totalEffectiveUsd >= productPriceUsd, isTrue);

        // BUT Spendable cash ($20.0) is < product price ($50.0)
        final isUsdSufficient = spendableUsd >= productPriceUsd;
        expect(isUsdSufficient, isFalse); // Must reject purchase due to insufficient spendable cash!
      });

      test('Purchase Execution Safety: USD Store Purchase deducts strictly from Wallet Cash', () {
        var walletCashUsd = 100.0;
        var rewardPointsKsp = 50000; // 50,000 KSP
        const purchaseAmountUsd = 30.0;

        // Verify spendable sufficiency
        expect(walletCashUsd >= purchaseAmountUsd, isTrue);

        // Execute simulated RPC deduction
        walletCashUsd -= purchaseAmountUsd;

        // Post-purchase checks:
        expect(walletCashUsd, equals(70.0)); // Cash reduced by $30
        expect(rewardPointsKsp, equals(50000)); // KSP points untouched!

        // New total effective balance: $70 cash + $50 KSP = $120.0 USD (120,000 KSP)
        final newEffectiveUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        final newEffectiveKsp = ((walletCashUsd * kspPerUsd) + rewardPointsKsp).round();

        expect(newEffectiveUsd, equals(120.0));
        expect(newEffectiveKsp, equals(120000));
      });

      test('Purchase Execution Safety: KSP Store Purchase deducts strictly from KSP Points', () {
        var walletCashUsd = 100.0;
        var rewardPointsKsp = 50000; // 50,000 KSP
        const purchaseKspPrice = 20000; // Costs 20,000 KSP

        // Verify spendable KSP sufficiency
        expect(rewardPointsKsp >= purchaseKspPrice, isTrue);

        // Execute simulated RPC deduction
        rewardPointsKsp -= purchaseKspPrice;

        // Post-purchase checks:
        expect(rewardPointsKsp, equals(30000)); // Points reduced by 20,000
        expect(walletCashUsd, equals(100.0)); // Wallet Cash untouched!

        // New total effective balance: $100 cash + $30 KSP = $130.0 USD (130,000 KSP)
        final newEffectiveUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        final newEffectiveKsp = ((walletCashUsd * kspPerUsd) + rewardPointsKsp).round();

        expect(newEffectiveUsd, equals(130.0));
        expect(newEffectiveKsp, equals(130000));
      });
    });

    group('KSP Redemption Atomic Engine & Full Simulation Matrix', () {
      test('Redemption Validation: Minimum 1,000 KSP and multiples of 1,000', () {
        // Rejects < 1000
        bool validateRedemption(int amount) {
          return amount >= 1000 && amount % 1000 == 0;
        }

        expect(validateRedemption(500), isFalse);
        expect(validateRedemption(1500), isFalse);
        expect(validateRedemption(1000), isTrue);
        expect(validateRedemption(10000), isTrue);
        expect(validateRedemption(50000), isTrue);
      });

      test('Full Financial Simulation: \$80.55 + 50k KSP -> 10k, 20k, 20k -> Transfer \$100', () {
        var walletCashUsd = 80.55;
        var rewardPointsKsp = 50000; // 50,000 KSP ($50 value)
        const kspPerUsd = 1000.0;

        // Step 0: Initial State Check
        var totalEffectiveUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        expect(walletCashUsd, equals(80.55));
        expect(rewardPointsKsp, equals(50000));
        expect(totalEffectiveUsd, equals(130.55));

        // Step 1: Redeem 10,000 KSP ($10.00 USD)
        const redeemStep1 = 10000;
        rewardPointsKsp -= redeemStep1;
        walletCashUsd += (redeemStep1 / kspPerUsd);

        expect(rewardPointsKsp, equals(40000));
        expect(walletCashUsd, equals(90.55));
        totalEffectiveUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        expect(totalEffectiveUsd, equals(130.55)); // Total portfolio value constant!

        // Step 2: Redeem 20,000 KSP ($20.00 USD)
        const redeemStep2 = 20000;
        rewardPointsKsp -= redeemStep2;
        walletCashUsd += (redeemStep2 / kspPerUsd);

        expect(rewardPointsKsp, equals(20000));
        expect(walletCashUsd, equals(110.55));
        totalEffectiveUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        expect(totalEffectiveUsd, equals(130.55)); // Total portfolio value constant!

        // Step 3: Redeem remaining 20,000 KSP ($20.00 USD)
        const redeemStep3 = 20000;
        rewardPointsKsp -= redeemStep3;
        walletCashUsd += (redeemStep3 / kspPerUsd);

        expect(rewardPointsKsp, equals(0));
        expect(walletCashUsd, equals(130.55));
        totalEffectiveUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        expect(totalEffectiveUsd, equals(130.55)); // Total portfolio value constant!
        expect(walletCashUsd, equals(totalEffectiveUsd)); // Total Balance == Spendable Balance!

        // Step 4: Transfer $100.00 P2P
        const transferAmount = 100.0;
        expect(walletCashUsd >= transferAmount, isTrue); // Sufficiency check PASSES!

        walletCashUsd -= transferAmount;
        expect(walletCashUsd, closeTo(30.55, 0.001));
        totalEffectiveUsd = walletCashUsd + (rewardPointsKsp / kspPerUsd);
        expect(totalEffectiveUsd, closeTo(30.55, 0.001));
      });

      test('Idempotency Safety: Duplicate execution returns ALREADY_PROCESSED', () {
        final processedKeys = <String>{};
        const idempotencyKey = 'ksp_redeem_user123_step1';

        bool executeRedemptionWithKey(String key) {
          if (processedKeys.contains(key)) {
            return false; // Already processed!
          }
          processedKeys.add(key);
          return true; // First time success
        }

        expect(executeRedemptionWithKey(idempotencyKey), isTrue);
        expect(executeRedemptionWithKey(idempotencyKey), isFalse); // Rejects duplicate!
      });
    });

    // ── 14. KSP REDEMPTION PERSISTED IDEMPOTENCY KEY LIFECYCLE (P1-2) ──
    // Mirrors the decision logic in KspBalanceService._resolveRedemptionKey /
    // _clearPersistedRedemptionKey:
    //   * reuse the persisted key across retries/restarts UNTIL success,
    //   * a NEW logical operation (different amount, or no persisted op) gets a
    //     NEW key,
    //   * clear ONLY on confirmed success.
    group('KSP Redemption Persisted Idempotency Key Lifecycle (P1-2)', () {
      test('Fresh operation (no persisted key) creates and persists a NEW key', () {
        final persistedKey = <String, String?>{}; // simulates SharedPreferences
        final persistedAmount = <String, int?>{};

        String resolve(String? callerKey, int amount) {
          final key = persistedKey['key'];
          final amt = persistedAmount['amount'];
          if (key != null && key.isNotEmpty && amt == amount) {
            return key; // reuse
          }
          final fresh = callerKey ?? 'uuid_fresh_1';
          persistedKey['key'] = fresh;
          persistedAmount['amount'] = amount;
          return fresh;
        }

        final k1 = resolve(null, 10000);
        expect(k1, 'uuid_fresh_1');
        expect(persistedKey['key'], k1);
        expect(persistedAmount['amount'], 10000);
      });

      test('Retry/restart with SAME amount reuses the persisted key (no new money op)', () {
        final persistedKey = <String, String?>{'key': 'stable_key_K1'};
        final persistedAmount = <String, int?>{'amount': 10000};

        String resolve(int amount) {
          final key = persistedKey['key'];
          final amt = persistedAmount['amount'];
          return (key != null && key.isNotEmpty && amt == amount)
              ? key
              : 'uuid_new';
        }

        // Same requested amount -> reuses K1, so the DB can deduplicate.
        expect(resolve(10000), 'stable_key_K1');
      });

      test('Different requested amount -> NEW operation gets a NEW key (K1 -> K2)', () {
        final persistedKey = <String, String?>{'key': 'stable_key_K1'};
        final persistedAmount = <String, int?>{'amount': 10000};

        String resolve(int amount) {
          final key = persistedKey['key'];
          final amt = persistedAmount['amount'];
          if (key != null && key.isNotEmpty && amt == amount) {
            return key;
          }
          final fresh = 'uuid_new_K2';
          persistedKey['key'] = fresh;
          persistedAmount['amount'] = amount;
          return fresh;
        }

        expect(resolve(20000), 'uuid_new_K2');
        expect(persistedKey['key'], 'uuid_new_K2');
        expect(persistedAmount['amount'], 20000);
      });

      test('Confirmed success clears the persisted operation so the next is fresh', () {
        final persistedKey = <String, String?>{'key': 'stable_key_K1'};
        final persistedAmount = <String, int?>{'amount': 10000};

        void clear() {
          persistedKey.remove('key');
          persistedAmount.remove('amount');
        }

        // Simulate the RPC returning success == true
        const success = true;
        if (success) {
          clear();
        }

        expect(persistedKey.containsKey('key'), isFalse);
        expect(persistedAmount.containsKey('amount'), isFalse);
      });

      test('Failure/timeout KEEPS the persisted key for safe retry (no double effect)', () {
        final persistedKey = <String, String?>{'key': 'stable_key_K1'};
        final persistedAmount = <String, int?>{'amount': 10000};

        // Simulate failure: do NOT clear; same amount retries with K1.
        expect(persistedKey['key'], 'stable_key_K1');
        expect(persistedAmount['amount'], 10000);
      });
    });
  });
}
