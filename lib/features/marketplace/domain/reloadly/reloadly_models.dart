/// DTOs aligned with Reloadly OpenAPI (`reloadly-api-documentation-main`).
class ReloadlyProductDto {
  final int productId;
  final String productName;
  final bool global;
  final double? senderFee;
  final double? discountPercentage;
  final String denominationType; // FIXED | RANGE
  final String recipientCurrencyCode;
  final double? minRecipientDenomination;
  final double? maxRecipientDenomination;
  final String senderCurrencyCode;
  final List<double> fixedRecipientDenominations;
  final List<String> logoUrls;
  final int brandId;
  final String brandName;
  final String? countryIso;
  final String? countryName;

  const ReloadlyProductDto({
    required this.productId,
    required this.productName,
    required this.global,
    this.senderFee,
    this.discountPercentage,
    required this.denominationType,
    required this.recipientCurrencyCode,
    this.minRecipientDenomination,
    this.maxRecipientDenomination,
    required this.senderCurrencyCode,
    this.fixedRecipientDenominations = const [],
    this.logoUrls = const [],
    required this.brandId,
    required this.brandName,
    this.countryIso,
    this.countryName,
  });

  factory ReloadlyProductDto.fromJson(Map<String, dynamic> json) {
    final brand = json['brand'] as Map<String, dynamic>?;
    final country = json['country'] as Map<String, dynamic>?;
    final logos = json['logoUrls'];
    final fixed = json['fixedRecipientDenominations'];

    return ReloadlyProductDto(
      productId: (json['productId'] as num).toInt(),
      productName: json['productName']?.toString() ?? '',
      global: json['global'] as bool? ?? false,
      senderFee: (json['senderFee'] as num?)?.toDouble(),
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble(),
      denominationType: json['denominationType']?.toString() ?? 'FIXED',
      recipientCurrencyCode: json['recipientCurrencyCode']?.toString() ?? 'USD',
      minRecipientDenomination:
          (json['minRecipientDenomination'] as num?)?.toDouble(),
      maxRecipientDenomination:
          (json['maxRecipientDenomination'] as num?)?.toDouble(),
      senderCurrencyCode: json['senderCurrencyCode']?.toString() ?? 'USD',
      fixedRecipientDenominations: fixed is List
          ? fixed.map((e) => (e as num).toDouble()).toList()
          : const [],
      logoUrls: logos is List ? logos.map((e) => e.toString()).toList() : const [],
      brandId: (brand?['brandId'] as num?)?.toInt() ?? 0,
      brandName: brand?['brandName']?.toString() ?? json['productName']?.toString() ?? '',
      countryIso: country?['isoName']?.toString(),
      countryName: country?['name']?.toString(),
    );
  }
}

class ReloadlyOrderResponseDto {
  final int transactionId;
  final double amount;
  final String currencyCode;
  final String status;
  final int productId;
  final String productName;

  const ReloadlyOrderResponseDto({
    required this.transactionId,
    required this.amount,
    required this.currencyCode,
    required this.status,
    required this.productId,
    required this.productName,
  });

  factory ReloadlyOrderResponseDto.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return ReloadlyOrderResponseDto(
      transactionId: (json['transactionId'] as num).toInt(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currencyCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      productId: (product?['productId'] as num?)?.toInt() ?? 0,
      productName: product?['productName']?.toString() ?? '',
    );
  }
}

class ReloadlyRedeemCodeDto {
  final String? cardNumber;
  final String? pinCode;
  final String? expirationDate;

  const ReloadlyRedeemCodeDto({
    this.cardNumber,
    this.pinCode,
    this.expirationDate,
  });

  factory ReloadlyRedeemCodeDto.fromJson(Map<String, dynamic> json) {
    return ReloadlyRedeemCodeDto(
      cardNumber: json['cardNumber']?.toString(),
      pinCode: json['pinCode']?.toString(),
      expirationDate: json['expirationDate']?.toString(),
    );
  }
}

class ReloadlyTransactionDto {
  final int transactionId;
  final double amount;
  final String currencyCode;
  final String status;
  final String? recipientEmail;
  final String? customIdentifier;
  final int? productId;
  final String? productName;

  const ReloadlyTransactionDto({
    required this.transactionId,
    required this.amount,
    required this.currencyCode,
    required this.status,
    this.recipientEmail,
    this.customIdentifier,
    this.productId,
    this.productName,
  });

  factory ReloadlyTransactionDto.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    return ReloadlyTransactionDto(
      transactionId: (json['transactionId'] as num).toInt(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currencyCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      recipientEmail: json['recipientEmail']?.toString(),
      customIdentifier: json['customIdentifier']?.toString(),
      productId: (product?['productId'] as num?)?.toInt(),
      productName: product?['productName']?.toString(),
    );
  }

  bool get isSuccessful =>
      status.toUpperCase() == 'SUCCESSFUL' || status.toUpperCase() == 'COMPLETED';
}

class ReloadlyRedeemInstructionDto {
  final int brandId;
  final String brandName;
  final String concise;
  final String verbose;

  const ReloadlyRedeemInstructionDto({
    required this.brandId,
    required this.brandName,
    required this.concise,
    required this.verbose,
  });

  factory ReloadlyRedeemInstructionDto.fromJson(Map<String, dynamic> json) {
    return ReloadlyRedeemInstructionDto(
      brandId: (json['brandId'] as num?)?.toInt() ?? 0,
      brandName: json['brandName']?.toString() ?? '',
      concise: json['concise']?.toString() ?? '',
      verbose: json['verbose']?.toString() ?? '',
    );
  }
}

class ReloadlyCatalogSyncResult {
  final List<ReloadlyProductDto> products;
  final int catalogCount;
  final List<String> countries;
  final List<Map<String, dynamic>> brands;
  final int? latencyMs;

  const ReloadlyCatalogSyncResult({
    required this.products,
    required this.catalogCount,
    this.countries = const [],
    this.brands = const [],
    this.latencyMs,
  });

  factory ReloadlyCatalogSyncResult.fromJson(Map<String, dynamic> json) {
    final raw = json['products'];
    final products = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => ReloadlyProductDto.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ReloadlyProductDto>[];
    return ReloadlyCatalogSyncResult(
      products: products,
      catalogCount: (json['catalogCount'] as num?)?.toInt() ?? products.length,
      countries: (json['countries'] as List?)?.map((e) => e.toString()).toList() ?? [],
      brands: (json['brands'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
    );
  }
}
