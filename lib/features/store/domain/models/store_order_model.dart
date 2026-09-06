import 'package:get/get.dart';

class StoreOrderModel {
  final String id;
  final String orderNumber;
  final String userId;
  final String? productId;
  final String productNameAr;
  final String productNameEn;
  final String? productImageUrl;
  final double amount;
  final String paymentMethod;
  final String status;
  final String deliveryCode;
  final String? serialNumber;
  final DateTime createdAt;

  const StoreOrderModel({
    required this.id,
    required this.orderNumber,
    required this.userId,
    this.productId,
    required this.productNameAr,
    required this.productNameEn,
    this.productImageUrl,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.deliveryCode,
    this.serialNumber,
    required this.createdAt,
  });

  factory StoreOrderModel.fromJson(Map<String, dynamic> json) {
    return StoreOrderModel(
      id: json['id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      productId: json['product_id'] as String?,
      productNameAr: json['product_name_ar'] as String? ?? '',
      productNameEn: json['product_name_en'] as String? ?? '',
      productImageUrl: json['product_image_url'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] as String? ?? 'wallet',
      status: json['status'] as String? ?? 'completed',
      deliveryCode: json['delivery_code'] as String? ?? '',
      serialNumber: json['serial_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  String get productName {
    final lang = Get.locale?.languageCode ?? 'ar';
    if (lang == 'en' && productNameEn.trim().isNotEmpty) {
      return productNameEn;
    }
    return productNameAr.isNotEmpty ? productNameAr : productNameEn;
  }
}
