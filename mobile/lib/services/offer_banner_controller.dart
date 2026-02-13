import 'dart:async';

import 'package:flutter/foundation.dart';
import 'offer_service.dart';
import '../models/offer_model.dart';

/// Singleton controller that manages offer banner state across the app.
/// Exposes a [ValueNotifier] so any widget can listen for changes.
class OfferBannerController {
  static final OfferBannerController _instance =
      OfferBannerController._internal();
  factory OfferBannerController() => _instance;
  OfferBannerController._internal();

  final OfferService _offerService = OfferService();

  /// Current offer banner result — null until the first fetch completes.
  final ValueNotifier<OfferFetchResult?> result =
      ValueNotifier<OfferFetchResult?>(null);

  /// Whether the user has dismissed the banner in this session.
  final ValueNotifier<bool> hiddenLocally = ValueNotifier<bool>(false);

  bool _fetching = false;

  /// Fetch (or re-fetch) the offer banner from the API.
  /// Safe to call multiple times — concurrent calls are debounced.
  Future<void> refresh({int retryCount = 0}) async {
    if (_fetching) return;
    _fetching = true;

    try {
      final fetchResult = await _offerService.fetchOfferBanner();

      print('[OfferCtrl] result: success=${fetchResult.success}, '
          'shouldShow=${fetchResult.shouldShowBanner}, '
          'hasOffer=${fetchResult.offer != null}, '
          'error=${fetchResult.error}');

      result.value = fetchResult;

      // Reset dismiss flag on successful fetch with a banner to show
      if (fetchResult.shouldShowBanner && fetchResult.offer != null) {
        hiddenLocally.value = false;
      }

      // Retry once after delay if no banner came back (cold start, timing)
      if (!fetchResult.shouldShowBanner && retryCount < 1) {
        Future.delayed(const Duration(seconds: 4), () {
          refresh(retryCount: retryCount + 1);
        });
      }
    } catch (e) {
      print('[OfferCtrl] fetch error: $e');
      if (retryCount < 1) {
        Future.delayed(const Duration(seconds: 4), () {
          refresh(retryCount: retryCount + 1);
        });
      }
    } finally {
      _fetching = false;
    }
  }

  /// Dismiss the banner for the rest of today.
  Future<void> dismiss() async {
    final offer = result.value?.offer;
    if (offer == null) return;

    hiddenLocally.value = true;
    await _offerService.dismissOfferForToday(offer.offerId);
  }

  /// Whether the banner should be visible right now.
  bool get shouldShow {
    final r = result.value;
    if (r == null) return false;
    if (!r.success) return false;
    if (r.offer == null) return false;
    if (!r.shouldShowBanner) return false;
    if (hiddenLocally.value) return false;
    return true;
  }

  /// Current offer (may be null).
  OfferModel? get offer => result.value?.offer;
}
