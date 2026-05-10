class LoanModel {
  final String id;
  final String userId;
  final double amount;
  final double interestRate;
  final double?
  totalDue; // generated column: amount + (amount * interest_rate / 100)
  final double remainingAmount;
  final double paidAmount;
  final String status; // pending, approved, active, partial_paid, paid, overdue, defaulted, rejected
  final DateTime? loanDate;
  final DateTime repaymentDate;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final String? rejectionReason;

  const LoanModel({
    required this.id,
    required this.userId,
    required this.amount,
    this.interestRate = 0.0,
    this.totalDue,
    this.remainingAmount = 0.0,
    this.paidAmount = 0.0,
    this.status = 'pending',
    this.loanDate,
    required this.repaymentDate,
    this.approvedBy,
    this.approvedAt,
    this.paidAt,
    this.createdAt,
    this.rejectionReason,
  });

  /// Remaining amount to be paid.
  double get calculatedRemaining => (totalDue ?? amount) - paidAmount;

  /// Payment progress as a fraction (0.0 to 1.0).
  double get paymentProgress {
    final total = totalDue ?? amount;
    if (total <= 0) return 0.0;
    return (paidAmount / total).clamp(0.0, 1.0);
  }

  factory LoanModel.fromJson(Map<String, dynamic> json) {
    return LoanModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      interestRate: (json['interest_rate'] as num?)?.toDouble() ?? 0.0,
      totalDue: (json['total_due'] as num?)?.toDouble(),
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble() ?? 
                       ((json['total_due'] as num?)?.toDouble() ?? (json['amount'] as num?)?.toDouble() ?? 0.0),
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      loanDate: json['loan_date'] != null
          ? DateTime.tryParse(json['loan_date'].toString())
          : null,
      repaymentDate: json['repayment_date'] != null 
          ? DateTime.tryParse(json['repayment_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'].toString())
          : null,
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'amount': amount,
      'interest_rate': interestRate,
      'paid_amount': paidAmount,
      'status': status,
      'repayment_date': repaymentDate.toIso8601String(),
      'rejection_reason': rejectionReason,
    };
  }

  LoanModel copyWith({
    String? id,
    String? userId,
    double? amount,
    double? interestRate,
    double? totalDue,
    double? remainingAmount,
    double? paidAmount,
    String? status,
    DateTime? loanDate,
    DateTime? repaymentDate,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? paidAt,
    String? rejectionReason,
  }) {
    return LoanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      interestRate: interestRate ?? this.interestRate,
      totalDue: totalDue ?? this.totalDue,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      loanDate: loanDate ?? this.loanDate,
      repaymentDate: repaymentDate ?? this.repaymentDate,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      paidAt: paidAt ?? this.paidAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
