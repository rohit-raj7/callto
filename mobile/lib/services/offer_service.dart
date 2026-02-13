import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/offer_model.dart';
import 'api_config.dart';
import 'api_service.dart';

class OfferService {
  static final OfferService _instance = OfferService._internal();
  factory OfferService() => _instance;
  OfferService._internal();

  final ApiService _api = ApiService();
  static const String _cachedBannerKey = 'offer_banner_cached_data';

  // ── API fetch ─────────────────────────────────────────────────────────

  /// Fetch offer banner from the backend and update the local cache.
  Future<OfferFetchResult> fetchOfferBanner() async {
    final response = await _api.get(ApiConfig.userOfferBanner);

    if (!response.isSuccess) {
      print('[OfferService] API call failed: ${response.error} '
          '(status: ${response.statusCode})');
      return OfferFetchResult(
        success: false,
        error: response.error ?? 'Failed to fetch offer banner',
      );
    }

    final payload = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};

    final activeOffer = payload['activeOffer'] == true;
    final bannerRaw = payload['offerBanner'];
    final walletBalance =
        (payload['walletBalance'] as num?)?.toDouble() ?? 0;
    final reason = payload['reason'];

    print('[OfferService] API: activeOffer=$activeOffer, '
        'walletBalance=$walletBalance, reason=$reason');

    // Banner not eligible (wallet sufficient or no active config)
    if (!activeOffer || bannerRaw is! Map) {
      // Update cached wallet balance so stale cache won't show banner
      if (reason == 'wallet_sufficient') {
        await _updateCachedWalletBalance(walletBalance);
      }
      return OfferFetchResult(
        success: true,
        shouldShowBanner: false,
        error: reason?.toString(),
      );
    }

    final offer =
        OfferModel.fromJson(Map<String, dynamic>.from(bannerRaw));

    // Cache banner + wallet balance for offline / instant display
    await _cacheBannerData(offer, walletBalance);

    print('[OfferService] offerId=${offer.offerId}, shouldShow=true, '
        'expiresAt=${offer.expiresAt}');

    return OfferFetchResult(
      success: true,
      offer: offer,
      shouldShowBanner: true,
    );
  }

  // ── Local cache ───────────────────────────────────────────────────────

  /// Load previously cached offer banner (no network call).
  Future<OfferFetchResult?> loadCachedOffer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedBannerKey);
      if (raw == null) return null;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final offerJson = data['offer'] as Map<String, dynamic>;
      final walletBalance =
          (data['walletBalance'] as num?)?.toDouble() ?? 0;
      final offer = OfferModel.fromJson(offerJson);

      // Don't show an expired or inactive cached banner
      if (offer.hasExpired || !offer.isActive) {
        print('[OfferService] Cached banner expired / inactive – clearing');
        await prefs.remove(_cachedBannerKey);
        return null;
      }

      final shouldShow = walletBalance < offer.minWalletBalance;

      print('[OfferService] Cache: offerId=${offer.offerId}, '
          'wallet=$walletBalance, min=${offer.minWalletBalance}, '
          'shouldShow=$shouldShow');

      return OfferFetchResult(
        success: true,
        offer: offer,
        shouldShowBanner: shouldShow,
      );
    } catch (e) {
      print('[OfferService] Cache load error: $e');
      return null;
    }
  }

  /// Save offer + wallet balance to SharedPreferences.
  Future<void> _cacheBannerData(
      OfferModel offer, double walletBalance) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'offer': offer.toJson(),
      'walletBalance': walletBalance,
      'cachedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_cachedBannerKey, jsonEncode(data));
    print('[OfferService] Cached banner: offerId=${offer.offerId}');
  }

  /// Update only the wallet balance inside the existing cache so that a
  /// "wallet_sufficient" API response correctly suppresses the cached banner.
  Future<void> _updateCachedWalletBalance(double walletBalance) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedBannerKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      data['walletBalance'] = walletBalance;
      await prefs.setString(_cachedBannerKey, jsonEncode(data));
      print('[OfferService] Updated cached wallet balance: $walletBalance');
    } catch (_) {}
  }
}

// ── Result model ──────────────────────────────────────────────────────────

class OfferFetchResult {
  final bool success;
  final OfferModel? offer;
  final bool shouldShowBanner;
  final String? error;

  const OfferFetchResult({
    required this.success,
    this.offer,
    this.shouldShowBanner = false,
    this.error,
  });
}
