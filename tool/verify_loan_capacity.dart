class LoanRecord {
  final String id;
  final String userId;
  final double amount;
  final String status;
  final double paidAmount;

  const LoanRecord({
    required this.id,
    required this.userId,
    required this.amount,
    required this.status,
    this.paidAmount = 0.0,
  });
}

void main() {
  print('================================================================');
  print('   KASBY 50% INVESTMENT-BACKED LOAN SYSTEM - VALIDATION SUITE   ');
  print('================================================================\n');

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

  double calculateExposure(List<LoanRecord> loans) {
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

  int passed = 0;
  int failed = 0;

  void assertCase(String name, bool condition, String details) {
    if (condition) {
      passed++;
      print('✅ [PASS] $name');
      print('   Details: $details\n');
    } else {
      failed++;
      print('❌ [FAIL] $name');
      print('   Details: $details\n');
    }
  }

  // Case 1: No Existing Loans
  {
    final invested = 1000.0;
    final cap = calculateTotalCapacity(invested, loanMaxPercentage);
    final exposure = calculateExposure([]);
    final remaining = calculateRemainingCapacity(cap, exposure);
    final allowed = validateLoanRequest(500.0, remaining);
    assertCase(
      'Case 1: No Existing Loans',
      cap == 500.0 && remaining == 500.0 && allowed == true,
      'Investment=\$1000, Capacity=\$500, Existing=\$0, Request=\$500 -> ALLOWED',
    );
  }

  // Case 2: Partial Existing Loan
  {
    final invested = 1000.0;
    final cap = calculateTotalCapacity(invested, loanMaxPercentage);
    final loans = [
      const LoanRecord(id: '1', userId: 'u1', amount: 200.0, status: 'pending', paidAmount: 0.0),
    ];
    final exposure = calculateExposure(loans);
    final remaining = calculateRemainingCapacity(cap, exposure);
    final allowed = validateLoanRequest(300.0, remaining);
    assertCase(
      'Case 2: Partial Existing Loan',
      exposure == 200.0 && remaining == 300.0 && allowed == true,
      'Investment=\$1000, Capacity=\$500, Existing=\$200, Request=\$300 -> ALLOWED',
    );
  }

  // Case 3: Exceeds Remaining Capacity
  {
    final invested = 1000.0;
    final cap = calculateTotalCapacity(invested, loanMaxPercentage);
    final loans = [
      const LoanRecord(id: '1', userId: 'u1', amount: 200.0, status: 'active', paidAmount: 0.0),
    ];
    final exposure = calculateExposure(loans);
    final remaining = calculateRemainingCapacity(cap, exposure);
    final allowed = validateLoanRequest(301.0, remaining);
    assertCase(
      'Case 3: Exceeds Remaining Capacity',
      exposure == 200.0 && remaining == 300.0 && allowed == false,
      'Investment=\$1000, Capacity=\$500, Existing=\$200, Request=\$301 -> REJECTED',
    );
  }

  // Case 4: Multiple Loans Reach Limit
  {
    final invested = 1000.0;
    final cap = calculateTotalCapacity(invested, loanMaxPercentage);
    final loans = [
      const LoanRecord(id: '1', userId: 'u1', amount: 200.0, status: 'active', paidAmount: 0.0),
      const LoanRecord(id: '2', userId: 'u1', amount: 300.0, status: 'pending', paidAmount: 0.0),
    ];
    final exposure = calculateExposure(loans);
    final remaining = calculateRemainingCapacity(cap, exposure);
    assertCase(
      'Case 4: Multiple Loans Reach Limit',
      exposure == 500.0 && remaining == 0.0,
      'Loan 1=\$200, Loan 2=\$300 -> Total Exposure=\$500, Remaining Capacity=\$0',
    );
  }

  // Case 5: Attempt After Reaching Limit
  {
    final invested = 1000.0;
    final cap = calculateTotalCapacity(invested, loanMaxPercentage);
    final loans = [
      const LoanRecord(id: '1', userId: 'u1', amount: 500.0, status: 'active', paidAmount: 0.0),
    ];
    final exposure = calculateExposure(loans);
    final remaining = calculateRemainingCapacity(cap, exposure);
    final allowed = validateLoanRequest(1.0, remaining);
    assertCase(
      'Case 5: Attempt After Reaching Limit',
      remaining == 0.0 && allowed == false,
      'Investment=\$1000, Capacity=\$500, Existing=\$500, Request=\$1 -> REJECTED',
    );
  }

  // Case 6: Multiple Investments Pooling
  {
    final invA = 1000.0;
    final invB = 2000.0;
    final totalInvested = invA + invB;
    final cap = calculateTotalCapacity(totalInvested, loanMaxPercentage);
    final remaining = calculateRemainingCapacity(cap, 0.0);
    assertCase(
      'Case 6: Multiple Investments Pooling',
      totalInvested == 3000.0 && cap == 1500.0 && validateLoanRequest(1500.0, remaining) == true && validateLoanRequest(1501.0, remaining) == false,
      'Inv A=\$1000 + Inv B=\$2000 = \$3000 -> 50% Capacity=\$1500 (No specific investment selection)',
    );
  }

  // Case 7: Rejected & Paid Loans
  {
    final invested = 1000.0;
    final cap = calculateTotalCapacity(invested, loanMaxPercentage);
    final loans = [
      const LoanRecord(id: 'paid', userId: 'u1', amount: 400.0, status: 'paid', paidAmount: 400.0),
      const LoanRecord(id: 'rejected', userId: 'u1', amount: 500.0, status: 'rejected', paidAmount: 0.0),
      const LoanRecord(id: 'cancelled', userId: 'u1', amount: 300.0, status: 'cancelled', paidAmount: 0.0),
      const LoanRecord(id: 'active', userId: 'u1', amount: 150.0, status: 'active', paidAmount: 50.0),
    ];
    final exposure = calculateExposure(loans);
    final remaining = calculateRemainingCapacity(cap, exposure);
    assertCase(
      'Case 7: Rejected & Paid Loans Excluded',
      exposure == 100.0 && remaining == 400.0 && validateLoanRequest(400.0, remaining) == true && validateLoanRequest(401.0, remaining) == false,
      'Paid(\$400), Rejected(\$500), Cancelled(\$300) excluded. Active remaining principal=\$100 -> Remaining Capacity=\$400',
    );
  }

  print('================================================================');
  print('RESULT: $passed / 7 Passed | $failed Failed');
  print('================================================================');
}
