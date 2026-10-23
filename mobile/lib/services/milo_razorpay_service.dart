import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/models.dart';
import '../services/milo_session_service.dart';

class MiloRazorpayService {
  MiloRazorpayService._();
  static final MiloRazorpayService instance = MiloRazorpayService._();

  Razorpay? _razorpay;

  // Default Razorpay Test Key for test & development verification
  static const String _defaultTestKey = 'rzp_test_5142MBKPCtest0';

  static const String razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: _defaultTestKey,
  );

  static bool get isConfigured => razorpayKey.isNotEmpty;

  void init() {
    _razorpay ??= Razorpay();
  }

  void openCheckout({
    required BuildContext context,
    required EventModel event,
    required TicketTier tier,
    required int quantity,
    required int amountPaise,
    String? orderId,
    required String attendeeName,
    required String attendeePhone,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    if (amountPaise <= 0) {
      debugPrint('Razorpay checkout blocked: invalid amount.');
      return;
    }
    init();

    _razorpay!.clear();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);

    final phone = attendeePhone.isNotEmpty
        ? attendeePhone
        : MiloSessionService.currentUserPhone;
    final name = attendeeName.isNotEmpty
        ? attendeeName
        : MiloSessionService.currentUserName;

    final options = {
      'key': razorpayKey,
      'amount': amountPaise,
      if (orderId != null && orderId.isNotEmpty) 'order_id': orderId,
      'currency': 'INR',
      'name': 'JHOOMO Events',
      'description': '${event.title} - ${tier.name} ($quantity Pass${quantity > 1 ? 'es' : ''})',
      'prefill': {
        if (phone.isNotEmpty) 'contact': phone,
        if (name.isNotEmpty) 'name': name,
      },
      'theme': {
        'color': '#E11D48', // JHOOMO Crimson Brand
      },
      'notes': {
        'eventId': event.id,
        'tierId': tier.id,
        'quantity': quantity.toString(),
        'uid': MiloSessionService.currentUid,
        'bookingOrderId': orderId,
      },
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      debugPrint('Milo Razorpay Open Error: $e');
    }
  }

  void dispose() {
    _razorpay?.clear();
  }
}
