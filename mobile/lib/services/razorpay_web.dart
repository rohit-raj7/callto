import 'dart:js_interop';

/// JS interop bindings for Razorpay Checkout.js (web only)
@JS('Razorpay')
extension type RazorpayJS._(JSObject _) implements JSObject {
  external factory RazorpayJS(JSObject options);
  external void open();
}

/// Helper to create Razorpay options as a JS object
JSObject buildRazorpayOptions({
  required String key,
  required int amount,
  required String currency,
  required String name,
  required String description,
  required String orderId,
  String? email,
  String? contact,
  required void Function(JSObject response) onSuccess,
  required void Function(JSObject response) onError,
  void Function(JSObject response)? onExternalWallet,
}) {
  final options = <String, dynamic>{
    'key': key.toJS,
    'amount': amount.toJS,
    'currency': currency.toJS,
    'name': name.toJS,
    'description': description.toJS,
    'order_id': orderId.toJS,
    'handler': onSuccess.toJS,
    'modal': {
      'ondismiss': (() {
        // User closed the modal — treat as payment cancelled
        final errorObj = _createJSObject();
        _setProperty(errorObj, 'code', 2.toJS);
        _setProperty(errorObj, 'description', 'Payment cancelled by user'.toJS);
        onError(errorObj);
      }).toJS,
    }.jsify(),
  }.jsify() as JSObject;

  // Add prefill if available
  final prefill = <String, dynamic>{};
  if (email != null && email.isNotEmpty) prefill['email'] = email.toJS;
  if (contact != null && contact.isNotEmpty) prefill['contact'] = contact.toJS;
  if (prefill.isNotEmpty) {
    _setProperty(options, 'prefill', prefill.jsify()!);
  }

  return options;
}

/// Extract payment_id from Razorpay JS success response
String? getPaymentId(JSObject response) {
  return _getStringProperty(response, 'razorpay_payment_id');
}

/// Extract order_id from Razorpay JS success response
String? getOrderId(JSObject response) {
  return _getStringProperty(response, 'razorpay_order_id');
}

/// Extract signature from Razorpay JS success response
String? getSignature(JSObject response) {
  return _getStringProperty(response, 'razorpay_signature');
}

/// Extract error code from Razorpay JS error response
int? getErrorCode(JSObject response) {
  final val = _getProperty(response, 'code');
  if (val == null) return null;
  return (val as JSNumber).toDartInt;
}

/// Extract error description from Razorpay JS error response
String? getErrorDescription(JSObject response) {
  // Razorpay error structure: response.error.description or response.description
  final errorObj = _getProperty(response, 'error');
  if (errorObj != null && errorObj is JSObject) {
    return _getStringProperty(errorObj, 'description');
  }
  return _getStringProperty(response, 'description');
}

// ---------- Internal JS helpers ----------

@JS('Object.create')
external JSObject _createJSObject();

@JS('Object.defineProperty')
void _setProperty(JSObject obj, String key, JSAny value) {
  _setPropertyJS(obj, key.toJS, value);
}

@JS('Reflect.set')
external void _setPropertyJS(JSObject target, JSString key, JSAny value);

JSAny? _getProperty(JSObject obj, String key) {
  return _getPropertyJS(obj, key.toJS);
}

@JS('Reflect.get')
external JSAny? _getPropertyJS(JSObject target, JSString key);

String? _getStringProperty(JSObject obj, String key) {
  final val = _getProperty(obj, key);
  if (val == null) return null;
  return (val as JSString).toDart;
}
