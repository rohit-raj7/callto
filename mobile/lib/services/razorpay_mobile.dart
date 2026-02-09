/// Mobile (Android/iOS) Razorpay implementation using razorpay_flutter package.
import 'package:razorpay_flutter/razorpay_flutter.dart';

Razorpay? _razorpay;

void Function(String? paymentId, String? orderId, String? signature)? _successCb;
void Function(int? code, String? message)? _errorCb;
void Function(String? walletName)? _externalWalletCb;

void initialize() {
  if (_razorpay != null) return;
  _razorpay = Razorpay();
  _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
  _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
  _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
}

void disposeRazorpay() {
  _razorpay?.clear();
  _razorpay = null;
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
  initialize();
  _successCb = onSuccess;
  _errorCb = onError;
  _externalWalletCb = onExternalWallet;

  final options = <String, dynamic>{
    'key': key,
    'amount': amount,
    'currency': currency,
    'name': name,
    'description': description,
    'order_id': orderId,
    'prefill': <String, dynamic>{
      if (email != null) 'email': email,
      if (contact != null) 'contact': contact,
    },
  };

  _razorpay!.open(options);
}

void _onSuccess(PaymentSuccessResponse response) {
  _successCb?.call(response.paymentId, response.orderId, response.signature);
}

void _onError(PaymentFailureResponse response) {
  _errorCb?.call(response.code, response.message);
}

void _onExternalWallet(ExternalWalletResponse response) {
  _externalWalletCb?.call(response.walletName);
}
