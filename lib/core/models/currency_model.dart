class CurrencyModel {
  final String id;
  final String name;
  final String code;
  final String symbol;
  final double rate;
  final int decimalPlaces;
  final bool isBase;
  final bool isActive;
  final String flag;
  final DateTime? updatedAt;

  const CurrencyModel({
    required this.id,
    required this.name,
    required this.code,
    this.symbol = '',
    required this.rate,
    this.decimalPlaces = 2,
    this.isBase = false,
    this.isActive = true,
    this.flag = '',
    this.updatedAt,
  });

  factory CurrencyModel.fromJson(Map<String, dynamic> json) {
    return CurrencyModel(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      symbol: json['symbol'] as String? ?? '',
      rate: (json['rate'] as num).toDouble(),
      decimalPlaces: json['decimal_places'] as int? ?? 2,
      isBase: json['is_base'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      flag: json['flag'] as String? ?? '',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'symbol': symbol,
      'rate': rate,
      'decimal_places': decimalPlaces,
      'is_base': isBase,
      'is_active': isActive,
      'flag': flag,
    };
  }

  CurrencyModel copyWith({
    String? id,
    String? name,
    String? code,
    String? symbol,
    double? rate,
    int? decimalPlaces,
    bool? isBase,
    bool? isActive,
    String? flag,
  }) {
    return CurrencyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      symbol: symbol ?? this.symbol,
      rate: rate ?? this.rate,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
      isBase: isBase ?? this.isBase,
      isActive: isActive ?? this.isActive,
      flag: flag ?? this.flag,
    );
  }
}
