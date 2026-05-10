class LoanRepaymentModel {
  final String id;
  final String loanId;
  final String userId;
  final double amount;
  final String type; // partial, full
  final double previousRemaining;
  final double newRemaining;
  final DateTime createdAt;

  LoanRepaymentModel({
    required this.id,
    required this.loanId,
    required this.userId,
    required this.amount,
    required this.type,
    required this.previousRemaining,
    required this.newRemaining,
    required this.createdAt,
  });

  factory LoanRepaymentModel.fromJson(Map<String, dynamic> json) {
    return LoanRepaymentModel(
      id: json['id'] as String? ?? '',
      loanId: json['loan_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] as String? ?? 'partial',
      previousRemaining: (json['previous_remaining'] as num?)?.toDouble() ?? 0.0,
      newRemaining: (json['new_remaining'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loan_id': loanId,
      'user_id': userId,
      'amount': amount,
      'type': type,
      'previous_remaining': previousRemaining,
      'new_remaining': newRemaining,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
