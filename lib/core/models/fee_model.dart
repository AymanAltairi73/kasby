class FeeModel {
  final String id;
  final String label;
  final String value;
  final double? percentage;
  final double? fixedAmount;
  final String category; // deposit, withdraw, investment, transfer, loan
  final bool isActive;
  final DateTime? createdAt;

  const FeeModel({
    required this.id,
    required this.label,
    required this.value,
    this.percentage,
    this.fixedAmount,
    required this.category,
    this.isActive = true,
    this.createdAt,
  });

  factory FeeModel.fromJson(Map<String, dynamic> json) {
    return FeeModel(
      id: json['id'] as String,
      label: json['label'] as String,
      value: json['value'] as String,
      percentage: (json['percentage'] as num?)?.toDouble(),
      fixedAmount: (json['fixed_amount'] as num?)?.toDouble(),
      category: json['category'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
      'percentage': percentage,
      'fixed_amount': fixedAmount,
      'category': category,
      'is_active': isActive,
    };
  }

  FeeModel copyWith({
    String? id,
    String? label,
    String? value,
    double? percentage,
    double? fixedAmount,
    String? category,
    bool? isActive,
  }) {
    return FeeModel(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      percentage: percentage ?? this.percentage,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
    );
  }
}
