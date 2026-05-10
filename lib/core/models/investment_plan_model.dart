class InvestmentPlanModel {
  final String id;
  final String nameAr;
  final String? nameEn;
  final String descriptionAr;
  final String? descriptionEn;
  final String? imageUrl;
  final double profitPercentage;
  final int? durationDays;
  final double minAmount;
  final double? maxAmount;
  final List<dynamic>? availableAmounts;
  final String riskLevel; // low, medium, high
  final bool isActive;
  final int version;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InvestmentPlanModel({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.descriptionAr = '',
    this.descriptionEn,
    this.imageUrl,
    required this.profitPercentage,
    this.durationDays,
    required this.minAmount,
    this.maxAmount,
    this.availableAmounts,
    this.riskLevel = 'medium',
    this.isActive = true,
    this.version = 1,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory InvestmentPlanModel.fromJson(Map<String, dynamic> json) {
    return InvestmentPlanModel(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String,
      nameEn: json['name_en'] as String?,
      descriptionAr: json['description_ar'] as String? ?? '',
      descriptionEn: json['description_en'] as String?,
      imageUrl: json['image_url'] as String?,
      profitPercentage: (json['profit_percentage'] as num).toDouble(),
      durationDays: json['duration_days'] as int?,
      minAmount: (json['min_amount'] as num).toDouble(),
      maxAmount: (json['max_amount'] as num?)?.toDouble(),
      availableAmounts: json['available_amounts'] as List<dynamic>?,
      riskLevel: json['risk_level'] as String? ?? 'medium',
      isActive: json['is_active'] as bool? ?? true,
      version: json['version'] as int? ?? 1,
      createdBy: json['created_by'] as String?,
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
      'name_ar': nameAr,
      'name_en': nameEn,
      'description_ar': descriptionAr,
      'description_en': descriptionEn,
      'image_url': imageUrl,
      'profit_percentage': profitPercentage,
      'duration_days': durationDays,
      'min_amount': minAmount,
      'max_amount': maxAmount,
      'available_amounts': availableAmounts,
      'risk_level': riskLevel,
      'is_active': isActive,
      'version': version,
      'created_by': createdBy,
    };
  }

  InvestmentPlanModel copyWith({
    String? id,
    String? nameAr,
    String? nameEn,
    String? descriptionAr,
    String? descriptionEn,
    String? imageUrl,
    double? profitPercentage,
    int? durationDays,
    double? minAmount,
    double? maxAmount,
    List<dynamic>? availableAmounts,
    String? riskLevel,
    bool? isActive,
    int? version,
    String? createdBy,
  }) {
    return InvestmentPlanModel(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      imageUrl: imageUrl ?? this.imageUrl,
      profitPercentage: profitPercentage ?? this.profitPercentage,
      durationDays: durationDays ?? this.durationDays,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      availableAmounts: availableAmounts ?? this.availableAmounts,
      riskLevel: riskLevel ?? this.riskLevel,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
