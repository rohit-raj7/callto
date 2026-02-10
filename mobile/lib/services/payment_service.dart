import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/recharge_pack_model.dart';
import 'api_config.dart';
import 'api_service.dart';

// Conditional imports for platform-specific Razorpay
import 'razorpay_stub.dart'
    if (dart.library.io) 'razorpay_mobile.dart'
    if (dart.library.html) 'razorpay_web_impl.dart'
    as razorpay_platform;

class PaymentService {
  PaymentService._internal();
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;

  final ApiService _apiService = ApiService();

  void initialize() {
    razorpay_platform.initialize();
  }

  void dispose() {
    razorpay_platform.disposeRazorpay();
  }

  Future<List<RechargePack>> getRechargePacks() async {
    try {
      final response = await _apiService.get(ApiConfig.rechargePacks);
      if (response.isSuccess && response.data != null && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        return data.map((json) => RechargePack.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching recharge packs: $e');
      return [];
    }
  }

  Future<void> openCheckout({
    required BuildContext context,
    required int amountInPaise,
    required String name,
    String? description,
    String? email,
    String? contact,
    void Function(dynamic response)? onSuccess,
    void Function(dynamic response)? onError,
    void Function(dynamic response)? onExternalWallet,
    void Function(String message)? onCheckoutError,
  }) async {
    final orderResponse = await _createOrder(amountInPaise);
    if (!orderResponse.isSuccess) {
      onCheckoutError?.call(orderResponse.error ?? 'Failed to create order');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(orderResponse.error ?? 'Failed to create order')),
        );
      }
      return;
    }

    final orderId = orderResponse.data['orderId']?.toString();
    final serverAmount = orderResponse.data['amount'];
    // Use key returned from backend to guarantee it matches the order
    final serverKeyId = orderResponse.data['keyId']?.toString();
    if (orderId == null || serverAmount == null) {
      onCheckoutError?.call('Order creation failed');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order creation failed')),
        );
      }
      return;
    }

    // Prefer key from backend response; fall back to local .env
    final keyId = (serverKeyId != null && serverKeyId.isNotEmpty)
        ? serverKeyId
        : (dotenv.env['RAZORPAY_KEY_ID']?.trim() ?? '');
    if (keyId.isEmpty) {
      onCheckoutError?.call('Razorpay key is missing');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Razorpay key is missing')),
        );
      }
      return;
    }

    try {
      razorpay_platform.openCheckout(
        key: keyId,
        amount: serverAmount is int ? serverAmount : int.tryParse(serverAmount.toString()) ?? amountInPaise,
        currency: 'INR',
        name: name,
        description: description ?? 'Wallet Top-Up',
        orderId: orderId,
        email: email,
        contact: contact,
        onSuccess: (paymentId, rpOrderId, signature) {
          if (paymentId != null && rpOrderId != null && signature != null) {
            _verifyPayment(
              paymentId: paymentId,
              orderId: rpOrderId,
              signature: signature,
            );
          }
          onSuccess?.call(_PaymentResult(paymentId: paymentId));
        },
        onError: (code, message) {
          debugPrint('Razorpay payment error: $code $message');
          onError?.call(_PaymentError(code: code, message: message));
        },
        onExternalWallet: (walletName) {
          debugPrint('Razorpay external wallet: $walletName');
          onExternalWallet?.call(_WalletResult(walletName: walletName));
        },
      );
    } catch (e) {
      debugPrint('Razorpay checkout error: $e');
      onCheckoutError?.call('Failed to launch checkout');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to launch checkout')),
        );
      }
    }
  }

  Future<ApiResponse> _createOrder(int amountInPaise) async {
    final response = await _apiService.post(
      '${ApiConfig.apiBase}/payments/create-order',
      body: {
        'amount': amountInPaise,
        'receipt': 'wallet_${DateTime.now().millisecondsSinceEpoch}',
      },
    );
    return response;
  }

  Future<void> _verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    await _apiService.post(
      '${ApiConfig.apiBase}/payments/verify-payment',
      body: {
        'razorpay_payment_id': paymentId,
        'razorpay_order_id': orderId,
        'razorpay_signature': signature,
      },
    );
  }
}

/// Lightweight result classes to unify web & mobile responses
class _PaymentResult {
  final String? paymentId;
  _PaymentResult({this.paymentId});
}

class _PaymentError {
  final int? code;
  final String? message;
  _PaymentError({this.code, this.message});
}

class _WalletResult {
  final String? walletName;
  _WalletResult({this.walletName});
}
