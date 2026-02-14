import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../services/storage_service.dart';
import '../../../services/user_service.dart';
import 'invoice_user.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _transactions = [];
  String _displayName = 'User';
  String _city = 'Karnataka';
  String _email = 'Not available';
  String _mobile = 'Not available';

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final formData = await _storageService.getUserFormData();
      final email = await _storageService.getEmail();
      final mobile = await _storageService.getMobile();
      final rawUserData = await _storageService.getUserData();

      UserResult? profileResult;
      try {
        profileResult = await _userService.getProfile();
      } catch (_) {
        profileResult = null;
      }

      final result = await _userService.getWallet();
      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isLoading = false;
          _error = result.error ?? 'Unable to load transactions.';
        });
        return;
      }

      final normalized = result.transactions
          .map(_normalizeTransaction)
          .whereType<Map<String, dynamic>>()
          .toList();

      normalized.sort((a, b) => _extractDate(b).compareTo(_extractDate(a)));

      Map<String, dynamic>? cachedUser;
      if (rawUserData != null && rawUserData.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawUserData);
          if (decoded is Map<String, dynamic>) {
            cachedUser = decoded;
          } else if (decoded is Map) {
            cachedUser = decoded.map(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
        } catch (_) {
          cachedUser = null;
        }
      }

      String fromMap(Map<String, dynamic>? data, List<String> keys) {
        if (data == null) return '';
        for (final key in keys) {
          final value = data[key];
          if (value == null) continue;
          final text = value.toString().trim();
          if (text.isNotEmpty) return text;
        }
        return '';
      }

      final formName = (formData['displayName'] ?? '').trim();
      final formCity = (formData['city'] ?? '').trim();
      final localEmail = (email ?? '').trim();
      final localMobile = (mobile ?? '').trim();
      final profileName =
          (profileResult?.user?.displayName ?? '').trim().isNotEmpty
          ? profileResult!.user!.displayName!.trim()
          : (profileResult?.user?.fullName ?? '').trim();
      final profileCity = (profileResult?.user?.city ?? '').trim();
      final profileEmail = (profileResult?.user?.email ?? '').trim();

      final cacheName = fromMap(cachedUser, [
        'display_name',
        'displayName',
        'full_name',
        'fullName',
        'name',
      ]);
      final cacheCity = fromMap(cachedUser, ['city', 'location']);
      final cacheEmail = fromMap(cachedUser, ['email', 'email_address']);
      final cacheMobile = fromMap(cachedUser, [
        'mobile',
        'phone',
        'mobile_number',
        'phone_number',
      ]);

      setState(() {
        _displayName = profileName.isNotEmpty
            ? profileName
            : (formName.isNotEmpty
                  ? formName
                  : (cacheName.isNotEmpty ? cacheName : 'User'));
        _city = profileCity.isNotEmpty
            ? profileCity
            : (formCity.isNotEmpty
                  ? formCity
                  : (cacheCity.isNotEmpty ? cacheCity : 'Karnataka'));
        _email = profileEmail.isNotEmpty
            ? profileEmail
            : (localEmail.isNotEmpty
                  ? localEmail
                  : (cacheEmail.isNotEmpty ? cacheEmail : 'Not available'));
        _mobile = localMobile.isNotEmpty
            ? localMobile
            : (cacheMobile.isNotEmpty ? cacheMobile : 'Not available');
        _transactions = normalized;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Something went wrong while loading transactions.';
      });
    }
  }

  Map<String, dynamic>? _normalizeTransaction(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// IST offset: +5 hours 30 minutes
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// Convert a UTC DateTime to IST (Asia/Kolkata, UTC+5:30)
  DateTime _toIST(DateTime utcDate) {
    return utcDate.toUtc().add(_istOffset);
  }

  DateTime _extractDate(Map<String, dynamic> txn) {
    final rawDate =
        txn['created_at'] ??
        txn['createdAt'] ??
        txn['date'] ??
        txn['timestamp'];

    if (rawDate == null) return DateTime.utc(1970);

    if (rawDate is int) {
      final millis = rawDate < 1000000000000 ? rawDate * 1000 : rawDate;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (rawDate is double) {
      final value = rawDate.toInt();
      final millis = value < 1000000000000 ? value * 1000 : value;
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    if (rawDate is String) {
      final numeric = int.tryParse(rawDate);
      if (numeric != null) {
        final millis = numeric < 1000000000000 ? numeric * 1000 : numeric;
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
      // ISO 8601 strings — DateTime.parse handles 'Z' and offset notation
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        return parsed.toUtc();
      }
      return DateTime.utc(1970);
    }

    return DateTime.utc(1970);
  }

  double _extractAmount(Map<String, dynamic> txn) {
    final value =
        txn['amount'] ?? txn['value'] ?? txn['total'] ?? txn['net_amount'];
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      return double.tryParse(cleaned) ?? 0;
    }
    return 0;
  }

  String _pickString(
    Map<String, dynamic> txn,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = txn[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  bool _isCredit(Map<String, dynamic> txn, double amount) {
    final type = _pickString(txn, [
      'transaction_type',
      'type',
      'direction',
      'entry_type',
    ]).toLowerCase();

    if (type.contains('credit') ||
        type.contains('add') ||
        type.contains('recharge') ||
        type.contains('deposit') ||
        type.contains('refund')) {
      return true;
    }

    if (type.contains('debit') ||
        type.contains('withdraw') ||
        type.contains('deduct') ||
        type.contains('spend') ||
        type.contains('charge')) {
      return false;
    }

    return amount >= 0;
  }

  String _transactionId(Map<String, dynamic> txn) {
    return _pickString(txn, [
      'transaction_id',
      'payment_gateway_id',
      'payment_id',
      'id',
    ], fallback: 'NA');
  }

  String _formatRupee(double amount) {
    return '\u20B9${amount.toStringAsFixed(2)}';
  }

  String _buildTitle(Map<String, dynamic> txn, bool isCredit, double amount) {
    final description = _pickString(txn, ['description', 'title', 'note']);
    if (description.isNotEmpty) {
      // Clean up bonus info from title — it's shown separately
      final bonusPattern = RegExp(r'\s*\+\s*₹[\d.]+\s*extra\s*bonus', caseSensitive: false);
      final cleaned = description.replaceAll(bonusPattern, '').trim();
      if (cleaned.isNotEmpty) {
        return cleaned[0].toUpperCase() + cleaned.substring(1);
      }
      return description[0].toUpperCase() + description.substring(1);
    }

    if (isCredit) {
      return 'Recharge of ${_formatRupee(amount)}';
    }

    final relatedCallId = _pickString(txn, ['related_call_id', 'call_id']);
    if (relatedCallId.isNotEmpty) {
      return 'Call with Expert';
    }
    return 'Wallet debit';
  }

  String? _extractBonusText(Map<String, dynamic> txn) {
    final description = _pickString(txn, ['description', 'title', 'note']);
    final match = RegExp(r'₹([\d.]+)\s*extra\s*bonus', caseSensitive: false).firstMatch(description);
    if (match != null) {
      return '+₹${match.group(1)} extra bonus included';
    }
    return null;
  }

  /// Whether a transaction is a call charge (debit with call-related data)
  bool _isCallCharge(Map<String, dynamic> txn) {
    final type = _pickString(txn, [
      'transaction_type',
      'type',
      'direction',
      'entry_type',
    ]).toLowerCase();
    final description = _pickString(txn, ['description', 'title', 'note']).toLowerCase();
    final hasCallId = _pickString(txn, ['related_call_id', 'call_id']).isNotEmpty;
    return (type == 'debit' && (description.contains('call charge') || hasCallId));
  }

  String _buildMetaText(DateTime utcDate, String transactionId, {bool hideTransactionId = false}) {
    if (utcDate.millisecondsSinceEpoch == 0 || utcDate.year == 1970) {
      return hideTransactionId ? '' : 'Txn ID: $transactionId';
    }

    final ist = _toIST(utcDate);
    final formatted = DateFormat('dd MMM yyyy, hh:mm a').format(ist);
    if (hideTransactionId) return formatted;
    return '$formatted | Txn ID: $transactionId';
  }

  Future<void> _copyTransactionId(String txnId) async {
    if (txnId == 'NA') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction ID not available')),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: txnId));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Transaction ID copied')));
  }

  void _openInvoice(
    Map<String, dynamic> txn,
    String title,
    bool isCredit,
    double amount,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceUserPage(
          transaction: txn,
          transactionTitle: title,
          userName: _displayName,
          userCity: _city,
          userEmail: _email,
          userMobile: _mobile,
          isCredit: isCredit,
          amount: amount,
        ),
      ),
    );
  }

  void _showHelpSheet(Map<String, dynamic> txn) {
    final txnId = _transactionId(txn);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Need help with this transaction?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Payment issue'),
                subtitle: Text('Reference: $txnId'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.headset_mic_outlined),
                title: const Text('Contact support'),
                subtitle: const Text('Email: support@callto.app'),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7DCE5),
        surfaceTintColor: const Color(0xFFF7DCE5),
        title: const Text(
          'Transactions',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Support',
            onPressed: () => _showHelpSheet(<String, dynamic>{}),
            icon: const Icon(Icons.support_agent_outlined),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFDEFEF), Color(0xFFF8E1F4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 44,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadTransactions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_transactions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadTransactions,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Icon(Icons.receipt_long_outlined, size: 52, color: Colors.grey),
            SizedBox(height: 8),
            Center(
              child: Text(
                'No transactions found',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final txn = _transactions[index];
          final rawAmount = _extractAmount(txn);
          final isCredit = _isCredit(txn, rawAmount);
          final amount = rawAmount.abs();
          final title = _buildTitle(txn, isCredit, amount);
          final bonusText = isCredit ? _extractBonusText(txn) : null;
          final txnId = _transactionId(txn);
          final date = _extractDate(txn);
          final isCallChargeTxn = _isCallCharge(txn);
          final isWalletRechargeTxn = isCredit && title.toLowerCase().contains('recharge');
          final metaText = _buildMetaText(date, txnId, hideTransactionId: !isWalletRechargeTxn);

          return _TransactionCard(
            title: title,
            bonusText: bonusText,
            metaText: metaText,
            amountText: '${isCredit ? '+' : '-'}${_formatRupee(amount)}',
            amountColor: isCredit
                ? const Color(0xFF1FA647)
                : const Color(0xFF1E1E1E),
            isCallCharge: isCallChargeTxn,
            isWalletRecharge: isWalletRechargeTxn,
            onCopyId: () => _copyTransactionId(txnId),
            onInvoice: () => _openInvoice(txn, title, isCredit, amount),
            onHelp: () => _showHelpSheet(txn),
          );
        },
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final String title;
  final String? bonusText;
  final String metaText;
  final String amountText;
  final Color amountColor;
  final bool isCallCharge;
  final bool isWalletRecharge;
  final VoidCallback onCopyId;
  final VoidCallback onInvoice;
  final VoidCallback onHelp;

  const _TransactionCard({
    required this.title,
    this.bonusText,
    required this.metaText,
    required this.amountText,
    required this.amountColor,
    this.isCallCharge = false,
    this.isWalletRecharge = false,
    required this.onCopyId,
    required this.onInvoice,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF880E4F),
                            ),
                          ),
                          if (bonusText != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                bonusText!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1FA647),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      amountText,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                if (metaText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          metaText,
                          style: const TextStyle(
                            color: Color(0xFF676767),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isWalletRecharge)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          splashRadius: 18,
                          iconSize: 20,
                          onPressed: onCopyId,
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Color(0xFF666666),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isWalletRecharge) ...[
            const Divider(height: 1, color: Color(0xFFE9E9E9)),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onInvoice,
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text('Invoice'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFD81B60),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, color: const Color(0xFFE9E9E9)),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onHelp,
                      icon: const Icon(Icons.headset_mic_outlined, size: 20),
                      label: const Text('Help'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF3B3B3B),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomRight: Radius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
