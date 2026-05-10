class SystemSettingsModel {
  final String id;
  final bool pauseDeposits;
  final bool pauseWithdrawals;
  final bool pauseProfits;
  final bool pauseInvestments;
  final bool pauseLoans;
  final bool systemFreeze;
  final bool isMaintenanceMode;
  final String maintenanceMessage;
  final DateTime? updatedAt;
  final String? updatedBy;

  const SystemSettingsModel({
    required this.id,
    this.pauseDeposits = false,
    this.pauseWithdrawals = false,
    this.pauseProfits = false,
    this.pauseInvestments = false,
    this.pauseLoans = false,
    this.systemFreeze = false,
    this.isMaintenanceMode = false,
    this.maintenanceMessage = '',
    this.updatedAt,
    this.updatedBy,
  });

  /// Whether any pause/freeze is active.
  bool get hasAnyPause =>
      pauseDeposits ||
      pauseWithdrawals ||
      pauseProfits ||
      pauseInvestments ||
      pauseLoans ||
      systemFreeze ||
      isMaintenanceMode;

  factory SystemSettingsModel.fromJson(Map<String, dynamic> json) {
    return SystemSettingsModel(
      id: json['id'] as String,
      pauseDeposits: json['pause_deposits'] as bool? ?? false,
      pauseWithdrawals: json['pause_withdrawals'] as bool? ?? false,
      pauseProfits: json['pause_profits'] as bool? ?? false,
      pauseInvestments: json['pause_investments'] as bool? ?? false,
      pauseLoans: json['pause_loans'] as bool? ?? false,
      systemFreeze: json['system_freeze'] as bool? ?? false,
      isMaintenanceMode: json['is_maintenance_mode'] as bool? ?? false,
      maintenanceMessage: json['maintenance_message'] as String? ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pause_deposits': pauseDeposits,
      'pause_withdrawals': pauseWithdrawals,
      'pause_profits': pauseProfits,
      'pause_investments': pauseInvestments,
      'pause_loans': pauseLoans,
      'system_freeze': systemFreeze,
      'is_maintenance_mode': isMaintenanceMode,
      'maintenance_message': maintenanceMessage,
      'updated_by': updatedBy,
    };
  }
}
