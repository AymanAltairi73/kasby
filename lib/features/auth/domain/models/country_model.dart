class Country {
  final String code;
  final String name;
  final String dialCode;
  final String flag;
  final bool isSupported;

  const Country({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.flag,
    this.isSupported = true,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      code: json['code'] as String,
      name: json['name'] as String,
      dialCode: json['dial_code'] as String,
      flag: json['flag'] as String? ?? '',
      isSupported: json['is_supported'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'dial_code': dialCode,
      'flag': flag,
      'is_supported': isSupported,
    };
  }
}
