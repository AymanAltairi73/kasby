class ProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String status; // active, blocked, suspended
  final String accountTier; // free, verified, vip
  final String kycStatus; // unverified, pending, verified, rejected
  final String? referralCode;
  final String? referredBy;
  final String? countryCode;
  final String? province;
  final String? city;
  final String? country;
  final String address;
  final String whatsapp;
  final String telegram;
  final String role; // user, admin, agent
  final DateTime? lastLoginAt;
  final String? lastLoginIp;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.status = 'active',
    this.accountTier = 'free',
    this.kycStatus = 'unverified',
    this.referralCode,
    this.referredBy,
    this.countryCode,
    this.province,
    this.city,
    this.country,
    this.address = '',
    this.whatsapp = '',
    this.telegram = '',
    this.lastLoginAt,
    this.lastLoginIp,
    this.createdAt,
    this.updatedAt,
    required this.role,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'active',
      accountTier: json['account_tier'] as String? ?? 'free',
      kycStatus: json['kyc_status'] as String? ?? 'unverified',
      role: json['role'] as String? ?? 'user',
      referralCode: json['referral_code'] as String?,
      referredBy: json['referred_by'] as String?,
      countryCode: json['country_code'] as String?,
      province: json['province'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      address: json['address'] as String? ?? '',
      whatsapp: json['whatsapp'] as String? ?? '',
      telegram: json['telegram'] as String? ?? '',
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'])
          : null,
      lastLoginIp: json['last_login_ip'] as String?,
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
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'status': status,
      'account_tier': accountTier,
      'kyc_status': kycStatus,
      'referral_code': referralCode,
      'referred_by': referredBy,
      'country_code': countryCode,
      'province': province,
      'city': city,
      'country': country,
      'address': address,
      'whatsapp': whatsapp,
      'telegram': telegram,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'last_login_ip': lastLoginIp,
      'role': role,
    };
  }

  ProfileModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    String? status,
    String? accountTier,
    String? kycStatus,
    String? referralCode,
    String? referredBy,
    String? countryCode,
    String? province,
    String? city,
    String? country,
    String? address,
    String? whatsapp,
    String? telegram,
    DateTime? lastLoginAt,
    String? lastLoginIp,
    String? role,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
      accountTier: accountTier ?? this.accountTier,
      kycStatus: kycStatus ?? this.kycStatus,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      countryCode: countryCode ?? this.countryCode,
      province: province ?? this.province,
      city: city ?? this.city,
      country: country ?? this.country,
      address: address ?? this.address,
      whatsapp: whatsapp ?? this.whatsapp,
      telegram: telegram ?? this.telegram,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLoginIp: lastLoginIp ?? this.lastLoginIp,
      role: role ?? this.role,
    );
  }
}
