class TopupProof {
  final String id;
  final String url;
  final String mime;
  final int sizeBytes;
  final DateTime? createdAt;

  TopupProof({
    required this.id,
    required this.url,
    required this.mime,
    required this.sizeBytes,
    this.createdAt,
  });

  factory TopupProof.fromJson(Map<String, dynamic> json) {
    return TopupProof(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      mime: json['mime'] as String? ?? 'image/png',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'mime': mime,
      'size_bytes': sizeBytes,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class TopupOrder {
  final String id;
  final String status; // queued, processing, awaiting_confirmation, fulfilled, failed, refunded
  final String sku;
  final String product;
  final Map<String, dynamic> player;
  final String provider;
  final bool isTest;
  final int attemptCount;
  final int amountCents;
  final int feeCents;
  final String idempotencyKey;
  final DateTime? createdAt;
  final DateTime? fulfilledAt;
  final DateTime? failedAt;
  final DateTime? refundedAt;
  final String? errorCode;
  final String? errorMessage;
  final int? confirmedPriceCents;
  final DateTime? confirmationExpiresAt;
  final String? deliveredCode;
  final String? batchId;
  final int? batchPosition;
  final List<TopupProof> proofs;

  TopupOrder({
    required this.id,
    required this.status,
    required this.sku,
    required this.product,
    required this.player,
    required this.provider,
    required this.isTest,
    required this.attemptCount,
    required this.amountCents,
    required this.feeCents,
    required this.idempotencyKey,
    this.createdAt,
    this.fulfilledAt,
    this.failedAt,
    this.refundedAt,
    this.errorCode,
    this.errorMessage,
    this.confirmedPriceCents,
    this.confirmationExpiresAt,
    this.deliveredCode,
    this.batchId,
    this.batchPosition,
    this.proofs = const [],
  });

  factory TopupOrder.fromJson(Map<String, dynamic> json) {
    return TopupOrder(
      id: json['id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      product: json['product'] as String? ?? '',
      player: json['player'] != null ? Map<String, dynamic>.from(json['player'] as Map) : {},
      provider: json['provider'] as String? ?? '',
      isTest: json['is_test'] as bool? ?? false,
      attemptCount: json['attempt_count'] as int? ?? 0,
      amountCents: json['amount_cents'] as int? ?? 0,
      feeCents: json['fee_cents'] as int? ?? 0,
      idempotencyKey: json['idempotency_key'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      fulfilledAt: json['fulfilled_at'] != null ? DateTime.tryParse(json['fulfilled_at'] as String) : null,
      failedAt: json['failed_at'] != null ? DateTime.tryParse(json['failed_at'] as String) : null,
      refundedAt: json['refunded_at'] != null ? DateTime.tryParse(json['refunded_at'] as String) : null,
      errorCode: json['error_code'] as String?,
      errorMessage: json['error_message'] as String?,
      confirmedPriceCents: json['confirmed_price_cents'] as int?,
      confirmationExpiresAt: json['confirmation_expires_at'] != null
          ? DateTime.tryParse(json['confirmation_expires_at'] as String)
          : null,
      deliveredCode: json['delivered_code'] as String?,
      batchId: json['batch_id'] as String?,
      batchPosition: json['batch_position'] as int?,
      proofs: (json['proofs'] as List?)
              ?.map((e) => TopupProof.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'sku': sku,
      'product': product,
      'player': player,
      'provider': provider,
      'is_test': isTest,
      'attempt_count': attemptCount,
      'amount_cents': amountCents,
      'fee_cents': feeCents,
      'idempotency_key': idempotencyKey,
      'created_at': createdAt?.toIso8601String(),
      'fulfilled_at': fulfilledAt?.toIso8601String(),
      'failed_at': failedAt?.toIso8601String(),
      'refunded_at': refundedAt?.toIso8601String(),
      'error_code': errorCode,
      'error_message': errorMessage,
      'confirmed_price_cents': confirmedPriceCents,
      'confirmation_expires_at': confirmationExpiresAt?.toIso8601String(),
      'delivered_code': deliveredCode,
      'batch_id': batchId,
      'batch_position': batchPosition,
      'proofs': proofs.map((e) => e.toJson()).toList(),
    };
  }

  TopupOrder copyWith({
    String? id,
    String? status,
    String? sku,
    String? product,
    Map<String, dynamic>? player,
    String? provider,
    bool? isTest,
    int? attemptCount,
    int? amountCents,
    int? feeCents,
    String? idempotencyKey,
    DateTime? createdAt,
    DateTime? fulfilledAt,
    DateTime? failedAt,
    DateTime? refundedAt,
    String? errorCode,
    String? errorMessage,
    int? confirmedPriceCents,
    DateTime? confirmationExpiresAt,
    String? deliveredCode,
    String? batchId,
    int? batchPosition,
    List<TopupProof>? proofs,
  }) {
    return TopupOrder(
      id: id ?? this.id,
      status: status ?? this.status,
      sku: sku ?? this.sku,
      product: product ?? this.product,
      player: player ?? this.player,
      provider: provider ?? this.provider,
      isTest: isTest ?? this.isTest,
      attemptCount: attemptCount ?? this.attemptCount,
      amountCents: amountCents ?? this.amountCents,
      feeCents: feeCents ?? this.feeCents,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      createdAt: createdAt ?? this.createdAt,
      fulfilledAt: fulfilledAt ?? this.fulfilledAt,
      failedAt: failedAt ?? this.failedAt,
      refundedAt: refundedAt ?? this.refundedAt,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      confirmedPriceCents: confirmedPriceCents ?? this.confirmedPriceCents,
      confirmationExpiresAt: confirmationExpiresAt ?? this.confirmationExpiresAt,
      deliveredCode: deliveredCode ?? this.deliveredCode,
      batchId: batchId ?? this.batchId,
      batchPosition: batchPosition ?? this.batchPosition,
      proofs: proofs ?? this.proofs,
    );
  }
}
