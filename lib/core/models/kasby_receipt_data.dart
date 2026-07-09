class KasbyReceiptData {
  final String transactionId;
  final String operationType;
  final String? referenceNumber;
  final DateTime date;
  final String? userName;
  final String? userId;
  final String? invitationCode;
  final double amount;
  final String currency;
  final String status;
  final double? walletBalanceAfter;
  final String? notes;
  final String? recipientName;
  final String? qrPayload;

  const KasbyReceiptData({
    required this.transactionId,
    required this.operationType,
    required this.date,
    required this.amount,
    this.referenceNumber,
    this.userName,
    this.userId,
    this.invitationCode,
    this.currency = 'USD',
    this.status = 'completed',
    this.walletBalanceAfter,
    this.notes,
    this.recipientName,
    this.qrPayload,
  });

  /// Backward-compatible factory for legacy receipt call sites.
  factory KasbyReceiptData.legacy({
    required String transactionId,
    required String recipientName,
    required double amount,
    required String type,
    required DateTime date,
  }) {
    return KasbyReceiptData(
      transactionId: transactionId,
      operationType: type,
      date: date,
      amount: amount,
      recipientName: recipientName,
    );
  }
}
