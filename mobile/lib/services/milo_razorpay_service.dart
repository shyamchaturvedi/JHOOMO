import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../models/models.dart';
import '../services/milo_session_service.dart';

class MiloRazorpayService {
  MiloRazorpayService._();
  static final MiloRazorpayService instance = MiloRazorpayService._();

  Razorpay? _razorpay;

  // Replace with production/test key or pass through compile flag --dart-define=RAZORPAY_KEY=rzp_live_xxx
  static const String razorpayKey = String.fromEnvironment(
    'RAZORPAY_KEY',
    defaultValue: 'rzp_test_1DP5mmOlF5G5ag', // Default Razorpay Test Key
  );

  void init() {
    _razorpay ??= Razorpay();
  }

  void openCheckout({
    required BuildContext context,
    required EventModel event,
    required TicketTier tier,
    required int quantity,
    required double totalAmount,
    required String attendeeName,
    required String attendeePhone,
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onError,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    init();

    _razorpay!.clear();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, onError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, onExternalWallet);

    final amountPaise = (totalAmount * 100).toInt();
    final phone = attendeePhone.isNotEmpty
        ? attendeePhone
        : (MiloSessionService.currentUserPhone.isNotEmpty ? MiloSessionService.currentUserPhone : '9876543210');
    final name = attendeeName.isNotEmpty
        ? attendeeName
        : (MiloSessionService.currentUserName.isNotEmpty ? MiloSessionService.currentUserName : 'JHOOMO Customer');

    final options = {
      'key': razorpayKey,
      'amount': amountPaise,
      'name': 'JHOOMO Events',
      'description': '${event.title} - ${tier.name} ($quantity Pass${quantity > 1 ? 'es' : ''})',
      'prefill': {
        'contact': phone,
        'email': 'customer@jhoomo.com',
        'name': name,
      },
      'theme': {
        'color': '#E11D48', // JHOOMO Crimson Brand
      },
      'notes': {
        'eventId': event.id,
        'tierId': tier.id,
        'quantity': quantity.toString(),
        'uid': MiloSessionService.currentUid,
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
