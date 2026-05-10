class WalletModel {
  final String id;
  final String userId;
  final double availableBalance;
  final double profitBalance;
  final double investedBalance;
  final double pendingBalance;
  final String currency;
  final bool isFrozen;
  final String? frozenReason;
  final DateTime? frozenAt;
  final String? frozenBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WalletModel({
    required this.id,
    required this.userId,
    this.availableBalance = 0.0,
    this.profitBalance = 0.0,
    this.investedBalance = 0.0,
    this.pendingBalance = 0.0,
    this.currency = 'USD',
    this.isFrozen = false,
    this.frozenReason,
    this.frozenAt,
    this.frozenBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Total balance across all balance types.
  double get totalBalance =>
      availableBalance + profitBalance + investedBalance + pendingBalance;

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0.0,
      profitBalance: (json['profit_balance'] as num?)?.toDouble() ?? 0.0,
      investedBalance: (json['invested_balance'] as num?)?.toDouble() ?? 0.0,
      pendingBalance: (json['pending_balance'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'USD',
      isFrozen: json['is_frozen'] as bool? ?? false,
      frozenReason: json['frozen_reason'] as String?,
      frozenAt: json['frozen_at'] != null
          ? DateTime.parse(json['frozen_at'])
          : null,
      frozenBy: json['frozen_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'available_balance': availableBalance,
      'profit_balance': profitBalance,
      'invested_balance': investedBalance,
      'pending_balance': pendingBalance,
      'currency': currency,
      'is_frozen': isFrozen,
      'frozen_reason': frozenReason,
      'frozen_at': frozenAt?.toIso8601String(),
      'frozen_by': frozenBy,
    };
  }

  WalletModel copyWith({
    String? id,
    String? userId,
    double? availableBalance,
    double? profitBalance,
    double? investedBalance,
    double? pendingBalance,
    String? currency,
    bool? isFrozen,
    String? frozenReason,
    DateTime? frozenAt,
    String? frozenBy,
  }) {
    return WalletModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      availableBalance: availableBalance ?? this.availableBalance,
      profitBalance: profitBalance ?? this.profitBalance,
      investedBalance: investedBalance ?? this.investedBalance,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      currency: currency ?? this.currency,
      isFrozen: isFrozen ?? this.isFrozen,
      frozenReason: frozenReason ?? this.frozenReason,
      frozenAt: frozenAt ?? this.frozenAt,
      frozenBy: frozenBy ?? this.frozenBy,
    );
  }
}
