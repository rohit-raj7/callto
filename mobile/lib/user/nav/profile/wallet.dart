import 'package:flutter/material.dart';
import '../../../models/recharge_pack_model.dart';
import '../../../services/payment_service.dart';
import '../../../services/user_service.dart';
import '../../../services/storage_service.dart';
import 'my_transaction.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int? _selectedIndex;
  final PaymentService _paymentService = PaymentService();
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();
  bool _isProcessing = false;
  bool _isLoadingPacks = true;
  double _walletBalance = 0.0;
  String? _prefillEmail;
  String? _prefillContact;
  List<RechargePack> _rechargePacks = [];

  @override
  void initState() {
    super.initState();
    _paymentService.initialize();
    _loadUserData();
    _loadRechargePacks();
  }

  Future<void> _loadRechargePacks() async {
    setState(() => _isLoadingPacks = true);
    final packs = await _paymentService.getRechargePacks();
    if (!mounted) return;
    setState(() {
      _rechargePacks = packs;
      _isLoadingPacks = false;
      if (_rechargePacks.isNotEmpty) {
        _selectedIndex = (_rechargePacks.length / 2).floor();
      } else {
        _selectedIndex = null;
      }
    });
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final email = await _storageService.getEmail();
    final mobile = await _storageService.getMobile();
    final walletResult = await _userService.getWallet();
    if (!mounted) return;
    setState(() {
      _prefillEmail = email;
      _prefillContact = mobile;
      if (walletResult.success) {
        _walletBalance = walletResult.balance;
      }
    });
  }

  void _setProcessing(bool value) {
    if (!mounted) return;
    setState(() => _isProcessing = value);
  }

  bool get _hasValidSelection {
    return _selectedIndex != null &&
        _selectedIndex! >= 0 &&
        _selectedIndex! < _rechargePacks.length;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final crossAxisCount = media.width > 600 ? 3 : 2;

    return Scaffold(
      // Gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDEFEF), Color(0xFFF8E1F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- AppBar replacement for gradient ---
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Wallet',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TransactionScreen(),
                          ),
                        );
                        _loadUserData();
                      },
                      icon: const Icon(Icons.swap_vert, color: Colors.pink),
                      label: const Text(
                        'Transactions',
                        style: TextStyle(color: Colors.pink),
                      ),
                    ),
                  ],
                ),
              ),

              // --- Balance card ---
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'My Balance',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '₹${_walletBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Section Title ---
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Balance to Wallet',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              // --- Grid of packs ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: _isLoadingPacks
                      ? const Center(child: CircularProgressIndicator())
                      : _rechargePacks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.info_outline,
                                      size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  const Text('No recharge packs available'),
                                  TextButton(
                                    onPressed: _loadRechargePacks,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              itemCount: _rechargePacks.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 2.5,
                              ),
                              itemBuilder: (context, index) {
                                final pack = _rechargePacks[index];
                                final selected = _selectedIndex == index;

                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedIndex = index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.pink.shade50
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: selected
                                          ? Border.all(
                                              color: Colors.pink, width: 2)
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.shade300,
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '₹${pack.amount.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.pink,
                                              ),
                                            ),
                                            if (pack.extraPercentOrAmount > 0)
                                              Text(
                                                '+${pack.extraPercentOrAmount.toStringAsFixed(0)}% extra',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (pack.badgeText != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              pack.badgeText!,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ),

              const SizedBox(height: 70),
            ],
          ),
        ),
      ),

      // --- Bottom CTA bar ---
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _hasValidSelection && _rechargePacks[_selectedIndex!].extraPercentOrAmount > 0
                      ? 'Pay ₹${_rechargePacks[_selectedIndex!].amount.toStringAsFixed(0)} → Get ₹${(_rechargePacks[_selectedIndex!].amount + _rechargePacks[_selectedIndex!].amount * _rechargePacks[_selectedIndex!].extraPercentOrAmount / 100).toStringAsFixed(2)} in wallet (+₹${(_rechargePacks[_selectedIndex!].amount * _rechargePacks[_selectedIndex!].extraPercentOrAmount / 100).toStringAsFixed(2)} extra)'
                      : _hasValidSelection
                          ? 'Pay ₹${_rechargePacks[_selectedIndex!].amount.toStringAsFixed(0)} → Get ₹${_rechargePacks[_selectedIndex!].amount.toStringAsFixed(2)} in wallet'
                          : 'Select a pack to add balance',
                  style: const TextStyle(color: Colors.green, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: _isProcessing || _isLoadingPacks || _rechargePacks.isEmpty || !_hasValidSelection
                    ? null
                    : () {
                        if (!_hasValidSelection) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select a pack')),
                          );
                          return;
                        }
                        final selected = _rechargePacks[_selectedIndex!];
                        final amount = selected.amount;
                        _initiateRazorpayPayment(amount, amount, selected);
                      },
                child: _isProcessing
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Add Balance',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== Razorpay Payment Flow =====
  void _initiateRazorpayPayment(double rechargeAmount, double payableAmount, RechargePack selectedPack) {
    final amountInPaise = (payableAmount * 100).round();
    _setProcessing(true);

    _paymentService.openCheckout(
      context: context,
      amountInPaise: amountInPaise,
      name: 'Call To',
      description: 'Wallet Recharge ₹${rechargeAmount.toStringAsFixed(0)}',
      email: _prefillEmail,
      contact: _prefillContact,
      onSuccess: (response) {
        _setProcessing(false);
        final paymentId = response?.paymentId?.toString() ?? 'N/A';
        _onPaymentSuccess(paymentId, rechargeAmount, selectedPack);
      },
      onError: (error) {
        _setProcessing(false);
        final msg = error?.message?.toString() ?? 'Payment failed. Please try again.';
        _showFailureDialog(msg);
      },
      onExternalWallet: (wallet) {
        _setProcessing(false);
        if (!mounted) return;
        final name = wallet?.walletName?.toString() ?? 'external wallet';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Redirecting to $name...'),
            backgroundColor: Colors.pinkAccent,
          ),
        );
      },
      onCheckoutError: (message) {
        _setProcessing(false);
        _showFailureDialog(message);
      },
    );
  }

  Future<void> _onPaymentSuccess(String paymentId, double rechargeAmount, RechargePack selectedPack) async {
    final result = await _userService.addBalance(
      rechargeAmount,
      paymentId: paymentId,
      packId: selectedPack.id,
    );
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _walletBalance = result.balance;
      });
      _showSuccessDialog(paymentId, rechargeAmount, result.bonusAmount, result.totalCredited);
    } else {
      _showFailureDialog('Payment received but wallet sync failed. Please contact support.');
    }
  }

  void _showSuccessDialog(String paymentId, double amount, double bonusAmount, double totalCredited) {
    final hasBonus = bonusAmount > 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              const Text('Payment Successful!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 10),
              if (hasBonus) ...[
                Text(
                  '₹${amount.toStringAsFixed(2)} + ₹${bonusAmount.toStringAsFixed(2)} extra',
                  style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total ₹${totalCredited.toStringAsFixed(2)} added to your wallet',
                  style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w500),
                ),
              ] else
                Text('₹${amount.toStringAsFixed(2)} added to your wallet',
                    style: const TextStyle(fontSize: 15, color: Colors.black54)),
              const SizedBox(height: 8),
              Text('Transaction ID: $paymentId',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFailureDialog(String message) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              const Text('Payment Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                if (_hasValidSelection) {
                  final selected = _rechargePacks[_selectedIndex!];
                  final amount = selected.amount;
                  _initiateRazorpayPayment(amount, amount, selected);
                }
              },
              child: const Text('Retry', style: TextStyle(color: Colors.pink)),
            ),
          ],
        );
      },
    );
  }
}
