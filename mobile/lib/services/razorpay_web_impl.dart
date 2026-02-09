/// Web implementation of Razorpay using Checkout.js via dart:js_interop.
import 'dart:js_interop';
import 'razorpay_web.dart';

void initialize() {
  // No-op on web — Razorpay JS is loaded via <script> in index.html
}

void disposeRazorpay() {
  // No-op on web
}

void openCheckout({
  required String key,
  required int amount,
  required String currency,
  required String name,
  required String description,
  required String orderId,
  String? email,
  String? contact,
  required void Function(String? paymentId, String? orderId, String? signature) onSuccess,
  required void Function(int? code, String? message) onError,
  void Function(String? walletName)? onExternalWallet,
}) {
  final options = buildRazorpayOptions(
    key: key,
    amount: amount,
    currency: currency,
    name: name,
    description: description,
    orderId: orderId,
    email: email,
    contact: contact,
    onSuccess: (JSObject response) {
      final paymentId = getPaymentId(response);
      final rpOrderId = getOrderId(response);
      final signature = getSignature(response);
      onSuccess(paymentId, rpOrderId, signature);
    },
    onError: (JSObject response) {
      final code = getErrorCode(response);
      final desc = getErrorDescription(response);
      onError(code, desc ?? 'Payment failed');
    },
  );

  final rzp = RazorpayJS(options);
  rzp.open();
}
