import 'package:get/get.dart';

class AgentModel {
  final String id;
  final String? userId;
  final String name;
  final String country;
  final String province;
  final String city;
  final String address;
  final String phone;
  final String whatsapp;
  final String telegram;
  final String email;
  final String status; // active, inactive, suspended
  final String availabilityStatus; // available, busy, unavailable
  final bool isAvailableNow;
  final List<String> supportedMethods;
  final double successRate;
  final int totalTransactions;
  final double escrowBalance;
  final double availableCash;
  final double maxCapacity;
  final double totalCommissionEarned;
  final DateTime? lastActiveAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AgentModel({
    required this.id,
    this.userId,
    required this.name,
    this.country = '',
    this.province = '',
    this.city = '',
    this.address = '',
    required this.phone,
    this.whatsapp = '',
    this.telegram = '',
    this.email = '',
    this.status = 'active',
    this.availabilityStatus = 'available',
    this.isAvailableNow = false,
    this.supportedMethods = const [],
    this.successRate = 0.0,
    this.totalTransactions = 0,
    this.escrowBalance = 0.0,
    this.availableCash = 0.0,
    this.maxCapacity = 1000.0,
    this.totalCommissionEarned = 0.0,
    this.lastActiveAt,
    this.createdAt,
    this.updatedAt,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    // Handle JOIN from profiles table - This is the Single Source of Truth
    // However, if the join fails (e.g. due to RLS), we fall back to agents table fields
    final profile = json['profiles'] as Map<String, dynamic>?;

    return AgentModel(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      // Fallback logic: Use profile if available, otherwise use agents table fields
      name: (profile?['full_name'] ?? json['name'] ?? '') as String,
      country:
          (profile?['country_code'] ?? json['country'] ?? 'iraq'.tr) as String,
      province: (profile?['province'] ?? json['province'] ?? '') as String,
      city:
          (profile?['city'] ?? json['city'] ?? json['province'] ?? '')
               as String,
      address: (profile?['address'] ?? json['address'] ?? '') as String,
      phone: (profile?['phone'] ?? json['phone'] ?? '') as String,
      whatsapp: (profile?['whatsapp'] ?? json['whatsapp'] ?? '') as String,
      telegram: (profile?['telegram'] ?? json['telegram'] ?? '') as String,
      email: (profile?['email'] ?? json['email'] ?? '') as String,
      status: (json['status'] ?? 'active') as String,
      availabilityStatus: (json['availability_status'] ?? (json['is_available_now'] == true ? 'available' : 'unavailable')) as String,
      isAvailableNow: json['is_available_now'] as bool? ?? false,
      supportedMethods:
          (json['supported_methods'] as List<dynamic>?)
               ?.map((e) => e.toString())
               .toList() ??
          [],
      successRate: (json['success_rate'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: json['total_transactions'] as int? ?? 0,
      escrowBalance: (json['escrow_balance'] as num?)?.toDouble() ?? 0.0,
      availableCash: (json['available_cash'] as num?)?.toDouble() ?? 0.0,
      maxCapacity: (json['max_capacity'] as num?)?.toDouble() ?? 1000.0,
      totalCommissionEarned: (json['total_commission_earned'] as num?)?.toDouble() ?? 0.0,
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.parse(json['last_active_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    // Only includes fields that belong to the agents table
    return {
      'user_id': userId,
      'status': status,
      'availability_status': availabilityStatus,
      'is_available_now': isAvailableNow,
      'supported_methods': supportedMethods,
      'success_rate': successRate,
      'total_transactions': totalTransactions,
      'escrow_balance': escrowBalance,
      'available_cash': availableCash,
      'max_capacity': maxCapacity,
      'total_commission_earned': totalCommissionEarned,
      'last_active_at': lastActiveAt?.toIso8601String(),
    };
  }

  AgentModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? country,
    String? province,
    String? city,
    String? address,
    String? phone,
    String? whatsapp,
    String? telegram,
    String? email,
    String? status,
    String? availabilityStatus,
    bool? isAvailableNow,
    List<String>? supportedMethods,
    double? successRate,
    int? totalTransactions,
    double? escrowBalance,
    double? availableCash,
    double? maxCapacity,
    double? totalCommissionEarned,
    DateTime? lastActiveAt,
  }) {
    return AgentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      country: country ?? this.country,
      province: province ?? this.province,
      city: city ?? this.city,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      telegram: telegram ?? this.telegram,
      email: email ?? this.email,
      status: status ?? this.status,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      isAvailableNow: isAvailableNow ?? this.isAvailableNow,
      supportedMethods: supportedMethods ?? this.supportedMethods,
      successRate: successRate ?? this.successRate,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      escrowBalance: escrowBalance ?? this.escrowBalance,
      availableCash: availableCash ?? this.availableCash,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      totalCommissionEarned: totalCommissionEarned ?? this.totalCommissionEarned,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
