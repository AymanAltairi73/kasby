import 'marketplace_order.dart';

class MarketplaceOrderTimelineEvent {
  final MarketplaceOrderStatus status;
  final DateTime timestamp;
  final String messageEn;
  final String messageAr;
  final bool isCompleted;
  final bool isCurrent;

  const MarketplaceOrderTimelineEvent({
    required this.status,
    required this.timestamp,
    required this.messageEn,
    required this.messageAr,
    this.isCompleted = false,
    this.isCurrent = false,
  });

  String localizedMessage(String locale) =>
      locale.startsWith('ar') ? messageAr : messageEn;
}

/// Builds a professional order timeline from order status and timestamps.
class MarketplaceOrderTimeline {
  MarketplaceOrderTimeline._();

  static const _happyPath = [
    MarketplaceOrderStatus.pending,
    MarketplaceOrderStatus.processing,
    MarketplaceOrderStatus.providerAccepted,
    MarketplaceOrderStatus.delivered,
    MarketplaceOrderStatus.completed,
  ];

  static List<MarketplaceOrderTimelineEvent> build(MarketplaceOrder order) {
    final status = order.status;
    final events = <MarketplaceOrderTimelineEvent>[];

    if (_isFailureStatus(status)) {
      return _buildFailureTimeline(order);
    }

    final currentIndex = _happyPath.indexOf(status);
    for (var i = 0; i < _happyPath.length; i++) {
      final s = _happyPath[i];
      final isCompleted = currentIndex >= 0 && i < currentIndex;
      final isCurrent = s == status;
      events.add(
        MarketplaceOrderTimelineEvent(
          status: s,
          timestamp: _timestampForStep(order, i, isCompleted, isCurrent),
          messageEn: _messageEn(s),
          messageAr: _messageAr(s),
          isCompleted: isCompleted,
          isCurrent: isCurrent,
        ),
      );
    }
    return events;
  }

  static bool _isFailureStatus(MarketplaceOrderStatus status) {
    return status == MarketplaceOrderStatus.failed ||
        status == MarketplaceOrderStatus.cancelled ||
        status == MarketplaceOrderStatus.refundRequested ||
        status == MarketplaceOrderStatus.refunded;
  }

  static List<MarketplaceOrderTimelineEvent> _buildFailureTimeline(
    MarketplaceOrder order,
  ) {
    final s = order.status;
    return [
      MarketplaceOrderTimelineEvent(
        status: MarketplaceOrderStatus.pending,
        timestamp: order.createdAt,
        messageEn: _messageEn(MarketplaceOrderStatus.pending),
        messageAr: _messageAr(MarketplaceOrderStatus.pending),
        isCompleted: true,
      ),
      MarketplaceOrderTimelineEvent(
        status: s,
        timestamp: order.updatedAt ?? order.createdAt,
        messageEn: _messageEn(s),
        messageAr: _messageAr(s),
        isCurrent: true,
      ),
    ];
  }

  static DateTime _timestampForStep(
    MarketplaceOrder order,
    int stepIndex,
    bool isCompleted,
    bool isCurrent,
  ) {
    if (isCurrent || isCompleted) {
      if (stepIndex == 0) return order.createdAt;
      if (order.timeline.isNotEmpty && stepIndex < order.timeline.length) {
        return order.timeline[stepIndex].timestamp;
      }
      return order.updatedAt ?? order.createdAt;
    }
    return order.createdAt;
  }

  static String _messageEn(MarketplaceOrderStatus s) {
    switch (s) {
      case MarketplaceOrderStatus.pending:
        return 'Order placed';
      case MarketplaceOrderStatus.processing:
        return 'Payment confirmed';
      case MarketplaceOrderStatus.providerAccepted:
        return 'Provider accepted order';
      case MarketplaceOrderStatus.delivered:
        return 'Digital delivery sent';
      case MarketplaceOrderStatus.completed:
        return 'Order completed';
      case MarketplaceOrderStatus.failed:
        return 'Order failed';
      case MarketplaceOrderStatus.cancelled:
        return 'Order cancelled';
      case MarketplaceOrderStatus.refundRequested:
        return 'Refund requested';
      case MarketplaceOrderStatus.refunded:
        return 'Refund processed';
    }
  }

  static String _messageAr(MarketplaceOrderStatus s) {
    switch (s) {
      case MarketplaceOrderStatus.pending:
        return 'تم تقديم الطلب';
      case MarketplaceOrderStatus.processing:
        return 'تم تأكيد الدفع';
      case MarketplaceOrderStatus.providerAccepted:
        return 'قبل المزود الطلب';
      case MarketplaceOrderStatus.delivered:
        return 'تم إرسال التسليم الرقمي';
      case MarketplaceOrderStatus.completed:
        return 'اكتمل الطلب';
      case MarketplaceOrderStatus.failed:
        return 'فشل الطلب';
      case MarketplaceOrderStatus.cancelled:
        return 'تم إلغاء الطلب';
      case MarketplaceOrderStatus.refundRequested:
        return 'طلب استرداد';
      case MarketplaceOrderStatus.refunded:
        return 'تم معالجة الاسترداد';
    }
  }
}
