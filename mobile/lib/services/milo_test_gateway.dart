import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Milo Pay — Test / Sandbox Payment Gateway 
///
/// A self-contained test payment API that mimics a real gateway
/// (order creation → payment capture → signed result) without needing any
/// merchant keys, so the full booking flow works end-to-end today.
///
/// Swapping in a real provider later only requires re-implementing
/// [MiloTestGateway.createOrder] / [MiloTestGateway.capture] against
/// Razorpay/Cashfree — the UI and booking flow stay unchanged.
///
/// Test rules (documented on the checkout sheet):
/// • Card `4111 1111 1111 1111` (or any other number) → SUCCESS
/// • Card ending `0002` → DECLINED
/// • UPI VPA `success@okaxis` / any (except fail) → SUCCESS
/// • UPI VPA containing `fail` / `decline` → FAILED
class MiloTestGateway {
  static const bool testMode = kDebugMode;
 static const String brandName = 'Milo Pay · Test Sandbox';
 static const String successUpi = 'success@okaxis';
 static const String failUpi = 'fail@okaxis';

 static const String successCard = '4111111111111111';
 static const String declineCard = '4000000000000002';

 static FirebaseFirestore? get _db {
 try {
 return FirebaseFirestore.instance;
 } catch (_) {
 return null;
 }
 }

 static String sanitizeCard(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

 /// Step 1 — create a payment order (like gateway order/create API).
 static Future<TestGatewayOrder> createOrder({
 required double amount,
 String currency = 'INR',
 Map<String, String> metadata = const {},
 }) async {
 final orderId = 'milo_test_order_${DateTime.now().millisecondsSinceEpoch}';
 final order = TestGatewayOrder(
 orderId: orderId,
 amount: amount,
 currency: currency,
 status: 'created',
 metadata: metadata,
 );
 await _recordPayment(
 orderId: orderId,
 status: 'created',
 amount: amount,
 method: '',
 metadata: metadata,
 );
 return order;
 }

 /// Step 2 — attempt capture of an order. Simulates gateway-side
 /// verification with the documented test-card / test-UPI rules.
 static Future<TestGatewayPaymentResult> capture({
 required TestGatewayOrder order,
 required String method, // 'card' | 'upi' | 'wallet'
 String? cardNumber,
 String? upiVpa,
 }) async {
 // Simulated network + 3-D Secure latency
 await Future.delayed(const Duration(milliseconds: 1500));

 bool success = true;
 String message = 'Payment successful';

 final digits = sanitizeCard(cardNumber ?? '');
 final vpa = (upiVpa ?? '').trim().toLowerCase();

 if (method == 'card') {
 if (digits.isEmpty) {
 success = false;
 message = 'Card number is required';
 } else if (digits.endsWith('0002')) {
 success = false;
 message = 'Card declined by issuer (sandbox rule: card ending 0002)';
 } else if (digits.length < 12) {
 success = false;
 message = 'Invalid card number';
 }
 } else if (method == 'upi') {
 if (vpa.isEmpty || !vpa.contains('@')) {
 success = false;
 message = 'Enter a valid UPI ID (e.g. $successUpi)';
 } else if (vpa.contains('fail') || vpa.contains('decline')) {
 success = false;
 message = 'UPI payment declined (sandbox rule: VPA containing "fail")';
 }
 }

 final paymentId =
 'pay_TEST_${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';

 await _recordPayment(
 orderId: order.orderId,
 status: success ? 'captured' : 'failed',
 amount: order.amount,
 method: method,
 paymentId: paymentId,
 metadata: {
 ...order.metadata,
 'method': method,
 if (cardNumber != null && digits.isNotEmpty)
 'card_last4': digits.length >= 4 ? digits.substring(digits.length - 4) : digits,
 if (upiVpa != null) 'upi': upiVpa,
 'message': message,
 },
 );

 return TestGatewayPaymentResult(
 success: success,
 paymentId: paymentId,
 orderId: order.orderId,
 method: method,
 message: message,
 amount: order.amount,
 );
 }

 static Future<void> _recordPayment({
 required String orderId,
 required String status,
 required double amount,
 required String method,
 String? paymentId,
 Map<String, String> metadata = const {},
 }) async {
 final db = _db;
 if (db == null) return;
 try {
 await db.collection('payments').doc(paymentId ?? orderId).set({
 'order_id': orderId,
 'payment_id': paymentId ?? '',
 'status': status,
 'amount': amount,
 'currency': 'INR',
 'method': method,
 'provider': 'milo_test_gateway',
 'test_mode': true,
 'metadata': metadata,
 'created_at': FieldValue.serverTimestamp(),
 'updated_at': FieldValue.serverTimestamp(),
 }, SetOptions(merge: true));
 } catch (e) {
 debugPrint('MiloTestGateway record note: $e');
 }
 }
}

class TestGatewayOrder {
 final String orderId;
 final double amount;
 final String currency;
 final String status;
 final Map<String, String> metadata;

 const TestGatewayOrder({
 required this.orderId,
 required this.amount,
 required this.currency,
 required this.status,
 this.metadata = const {},
 });
}

class TestGatewayPaymentResult {
 final bool success;
 final String paymentId;
 final String orderId;
 final String method;
 final String message;
 final double amount;

 const TestGatewayPaymentResult({
 required this.success,
 required this.paymentId,
 required this.orderId,
 required this.method,
 required this.message,
 required this.amount,
 });
}
