/// Stub implementation — should never be called.
/// The conditional import will pick razorpay_mobile.dart or razorpay_web_impl.dart.

void initialize() {}

void disposeRazorpay() {}

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
  throw UnsupportedError('Razorpay is not supported on this platform');
}
