import 'package:shared_preferences/shared_preferences.dart';

import '../models/offer_model.dart';
import 'api_config.dart';
import 'api_service.dart';

class OfferService {
  static final OfferService _instance = OfferService._internal();
  factory OfferService() => _instance;
  OfferService._internal();

  final ApiService _api = ApiService();
  static const String _dismissedDayPrefix = 'offer_banner_dismissed_day_';

  Future<OfferFetchResult> fetchOfferBanner() async {
    final response = await _api.get(ApiConfig.userOfferBanner);

    if (!response.isSuccess) {
      print('[OfferService] API call failed: ${response.error} (status: ${response.statusCode})');
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
    final walletBalance = payload['walletBalance'];
    final reason = payload['reason'];

    print('[OfferService] RAW API response: $payload');
    print('[OfferService] activeOffer=$activeOffer, walletBalance=$walletBalance, '
        'hasBannerData=${bannerRaw is Map}, reason=$reason');

    if (!activeOffer || bannerRaw is! Map) {
      print('[OfferService] Banner not eligible: activeOffer=$activeOffer, '
          'reason=$reason, bannerRaw type=${bannerRaw.runtimeType}');
      return OfferFetchResult(
        success: true,
        shouldShowBanner: false,
        error: reason?.toString(),
      );
    }

    final offer = OfferModel.fromJson(Map<String, dynamic>.from(bannerRaw));
    final dismissedToday = await isDismissedForToday(offer.offerId);
    // Backend already enforces active flag + time window + wallet eligibility.
    final shouldShow = activeOffer && !dismissedToday;

    print('[OfferService] offerId=${offer.offerId}, dismissedToday=$dismissedToday, shouldShow=$shouldShow, expiresAt=${offer.expiresAt}');

    return OfferFetchResult(
      success: true,
      offer: offer,
      shouldShowBanner: shouldShow,
      dismissedToday: dismissedToday,
    );
  }

  Future<void> dismissOfferForToday(String offerId) async {
    if (offerId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_dismissedDayPrefix$offerId', _todayKey());
  }

  Future<bool> isDismissedForToday(String offerId) async {
    if (offerId.trim().isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_dismissedDayPrefix$offerId';
    final storedDay = prefs.getString(key);
    if (storedDay == null) return false;

    final today = _todayKey();
    if (storedDay == today) {
      return true;
    }

    await prefs.remove(key);
    return false;
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}

class OfferFetchResult {
  final bool success;
  final OfferModel? offer;
  final bool shouldShowBanner;
  final bool dismissedToday;
  final String? error;

  const OfferFetchResult({
    required this.success,
    this.offer,
    this.shouldShowBanner = false,
    this.dismissedToday = false,
    this.error,
  });
}
