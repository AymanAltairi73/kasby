class KycDocumentModel {
  final String id;
  final String userId;
  final String
  documentType; // id_card_front, id_card_back, passport, selfie, proof_of_address, other
  final String documentUrl;
  final String status; // pending, verified, rejected, unverified
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime? uploadedAt;

  const KycDocumentModel({
    required this.id,
    required this.userId,
    required this.documentType,
    required this.documentUrl,
    this.status = 'pending',
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.uploadedAt,
  });

  /// Whether this document is still awaiting review.
  bool get isPending => status == 'pending';

  /// Whether this document has been approved.
  bool get isVerified => status == 'verified';

  factory KycDocumentModel.fromJson(Map<String, dynamic> json) {
    return KycDocumentModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      documentType: json['document_type'] as String,
      documentUrl: json['document_url'] as String,
      status: json['status'] as String? ?? 'pending',
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'document_type': documentType,
      'document_url': documentUrl,
      'status': status,
    };
  }

  KycDocumentModel copyWith({
    String? id,
    String? userId,
    String? documentType,
    String? documentUrl,
    String? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
  }) {
    return KycDocumentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      documentType: documentType ?? this.documentType,
      documentUrl: documentUrl ?? this.documentUrl,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
