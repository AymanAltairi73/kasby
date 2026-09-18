import 'package:flutter_test/flutter_test.dart';
import 'package:kasby/core/models/loan_model.dart';

void main() {
  group('50% Investment-Backed Loan System Unit Tests', () {
    const double loanMaxPercentage = 0.50;

    const exposureStatuses = {
      'pending',
      'approved',
      'active',
      'current',
      'partial_paid',
      'delayed',
      'overdue',
    };

    double calculateTotalCapacity(double investedBalance, double percentage) {
      return (investedBalance * percentage);
    }

    double calculateExposure(List<LoanModel> loans) {
      double total = 0.0;
      for (final loan in loans) {
        if (exposureStatuses.contains(loan.status)) {
          final remainingPrincipal = loan.amount - loan.paidAmount;
          if (remainingPrincipal > 0) {
            total += remainingPrincipal;
          }
        }
      }
      return total;
    }

    double calculateRemainingCapacity(double totalCapacity, double exposure) {
      final rem = totalCapacity - exposure;
      return rem > 0 ? rem : 0.0;
    }

    bool validateLoanRequest(double requestAmount, double remainingCapacity) {
      if (requestAmount <= 0) return false;
      return requestAmount <= remainingCapacity;
    }

    // ── Case 1: No Existing Loans ──
    test('Case 1: No Existing Loans - Request equals 50% capacity', () {
      final investedBalance = 1000.0;
      final totalCapacity = calculateTotalCapacity(investedBalance, loanMaxPercentage);
      expect(totalCapacity, equals(500.0));

      final loans = <LoanModel>[];
      final exposure = calculateExposure(loans);
      expect(exposure, equals(0.0));

      final remaining = calculateRemainingCapacity(totalCapacity, exposure);
      expect(remaining, equals(500.0));

      final isAllowed = validateLoanRequest(500.0, remaining);
      expect(isAllowed, isTrue);
    });

    // ── Case 2: Partial Existing Loan ──
    test('Case 2: Partial Existing Loan - Request fits in remaining capacity', () {
      final investedBalance = 1000.0;
      final totalCapacity = calculateTotalCapacity(investedBalance, loanMaxPercentage);

      final loans = [
        const LoanModel(
          id: 'loan-1',
          userId: 'user-1',
          amount: 200.0,
          status: 'pending',
          paidAmount: 0.0,
        ),
      ];
      final exposure = calculateExposure(loans);
      expect(exposure, equals(200.0));

      final remaining = calculateRemainingCapacity(totalCapacity, exposure);
      expect(remaining, equals(300.0));

      final isAllowed = validateLoanRequest(300.0, remaining);
      expect(isAllowed, isTrue);
    });

    // ── Case 3: Exceeds Remaining Capacity ──
    test('Case 3: Exceeds Remaining Capacity - Request is rejected', () {
      final investedBalance = 1000.0;
      final totalCapacity = calculateTotalCapacity(investedBalance, loanMaxPercentage);

      final loans = [
        const LoanModel(
          id: 'loan-1',
          userId: 'user-1',
          amount: 200.0,
          status: 'active',
          paidAmount: 0.0,
        ),
      ];
      final exposure = calculateExposure(loans);
      final remaining = calculateRemainingCapacity(totalCapacity, exposure);
      expect(remaining, equals(300.0));

      final isAllowed = validateLoanRequest(301.0, remaining);
      expect(isAllowed, isFalse);
    });

    // ── Case 4: Multiple Loans Reach Limit ──
    test('Case 4: Multiple Loans Reach Limit - Both allowed, remaining becomes 0', () {
      final investedBalance = 1000.0;
      final totalCapacity = calculateTotalCapacity(investedBalance, loanMaxPercentage);

      // First loan: 200
      var loans = <LoanModel>[];
      var remaining = calculateRemainingCapacity(totalCapacity, calculateExposure(loans));
      expect(validateLoanRequest(200.0, remaining), isTrue);

      loans.add(const LoanModel(
        id: 'loan-1',
        userId: 'user-1',
        amount: 200.0,
        status: 'active',
        paidAmount: 0.0,
      ));

      // Second loan: 300
      remaining = calculateRemainingCapacity(totalCapacity, calculateExposure(loans));
      expect(remaining, equals(300.0));
      expect(validateLoanRequest(300.0, remaining), isTrue);

      loans.add(const LoanModel(
        id: 'loan-2',
        userId: 'user-1',
        amount: 300.0,
        status: 'pending',
        paidAmount: 0.0,
      ));

      // Exposure is now 500, remaining is 0
      final finalExposure = calculateExposure(loans);
      expect(finalExposure, equals(500.0));

      final finalRemaining = calculateRemainingCapacity(totalCapacity, finalExposure);
      expect(finalRemaining, equals(0.0));
    });

    // ── Case 5: Attempt After Reaching Limit ──
    test('Case 5: Attempt After Reaching Limit - Request is rejected', () {
      final investedBalance = 1000.0;
      final totalCapacity = calculateTotalCapacity(investedBalance, loanMaxPercentage);

      final loans = [
        const LoanModel(
          id: 'loan-1',
          userId: 'user-1',
          amount: 500.0,
          status: 'active',
          paidAmount: 0.0,
        ),
      ];
      final exposure = calculateExposure(loans);
      final remaining = calculateRemainingCapacity(totalCapacity, exposure);
      expect(remaining, equals(0.0));

      final isAllowed = validateLoanRequest(1.0, remaining);
      expect(isAllowed, isFalse);
    });

    // ── Case 6: Multiple Investments Pooling ──
    test('Case 6: Multiple Investments Pooling - Total invested balance aggregates', () {
      final investmentA = 1000.0;
      final investmentB = 2000.0;
      final totalActiveInvestment = investmentA + investmentB;
      expect(totalActiveInvestment, equals(3000.0));

      final totalCapacity = calculateTotalCapacity(totalActiveInvestment, loanMaxPercentage);
      expect(totalCapacity, equals(1500.0));

      final remaining = calculateRemainingCapacity(totalCapacity, 0.0);
      expect(remaining, equals(1500.0));

      expect(validateLoanRequest(1500.0, remaining), isTrue);
      expect(validateLoanRequest(1501.0, remaining), isFalse);
    });

    // ── Case 7: Rejected & Paid Loans Excluded From Exposure ──
    test('Case 7: Rejected and Paid Loans do not consume borrowing capacity', () {
      final investedBalance = 1000.0;
      final totalCapacity = calculateTotalCapacity(investedBalance, loanMaxPercentage);

      final loans = [
        const LoanModel(
          id: 'loan-paid',
          userId: 'user-1',
          amount: 400.0,
          status: 'paid',
          paidAmount: 400.0,
        ),
        const LoanModel(
          id: 'loan-rejected',
          userId: 'user-1',
          amount: 500.0,
          status: 'rejected',
          paidAmount: 0.0,
        ),
        const LoanModel(
          id: 'loan-cancelled',
          userId: 'user-1',
          amount: 300.0,
          status: 'cancelled',
          paidAmount: 0.0,
        ),
        const LoanModel(
          id: 'loan-active',
          userId: 'user-1',
          amount: 150.0,
          status: 'active',
          paidAmount: 50.0, // partially paid, remaining principal is 100
        ),
      ];

      final exposure = calculateExposure(loans);
      // Only loan-active counts, with remaining principal: 150 - 50 = 100
      expect(exposure, equals(100.0));

      final remaining = calculateRemainingCapacity(totalCapacity, exposure);
      expect(remaining, equals(400.0));

      expect(validateLoanRequest(400.0, remaining), isTrue);
      expect(validateLoanRequest(401.0, remaining), isFalse);
    });
  });
}
