import 'package:flutter/foundation.dart';
import 'offer_service.dart';
import '../models/offer_model.dart';

/// Singleton controller that manages offer banner state across the app.
///
/// Data flow:
///   1. [refresh] loads cached data first → instant banner display
///   2. Then fetches from backend in the same call → updates cache
///   3. [resetDismiss] is called when the Home screen becomes visible
///      so the banner reappears on every visit.
class OfferBannerController {
  static final OfferBannerController _instance =
      OfferBannerController._internal();
  factory OfferBannerController() => _instance;
  OfferBannerController._internal();

  final OfferService _offerService = OfferService();

  /// Current offer banner result — null until the first load completes.
  final ValueNotifier<OfferFetchResult?> result =
      ValueNotifier<OfferFetchResult?>(null);

  /// Whether the user has pressed the close button in this viewing.
  final ValueNotifier<bool> hiddenLocally = ValueNotifier<bool>(false);

  bool _fetching = false;

  // ── Public API ────────────────────────────────────────────────────────

  /// Load offer banner: cache first, then background API sync.
  /// Safe to call many times — concurrent calls are debounced.
  Future<void> refresh() async {
    if (_fetching) return;
    _fetching = true;

    try {
      // 1) Instant display from cache (only when we have no data yet)
      if (result.value == null ||
          result.value?.offer == null) {
        final cached = await _offerService.loadCachedOffer();
        if (cached != null && cached.offer != null) {
          result.value = cached;
          print('[OfferCtrl] Loaded from cache: '
              'shouldShow=${cached.shouldShowBanner}');
        }
      }

      // 2) Sync from API → updates cache automatically
      final apiResult = await _offerService.fetchOfferBanner();

      print('[OfferCtrl] API result: success=${apiResult.success}, '
          'shouldShow=${apiResult.shouldShowBanner}, '
          'hasOffer=${apiResult.offer != null}');

      // Only overwrite with API result if it succeeded
      if (apiResult.success) {
        result.value = apiResult;
      }
    } catch (e) {
      print('[OfferCtrl] refresh error: $e');
      // If API fails and we still have no data, try cache as fallback
      if (result.value == null) {
        final cached = await _offerService.loadCachedOffer();
        if (cached != null) result.value = cached;
      }
    } finally {
      _fetching = false;
    }
  }

  /// Reset the dismiss flag so the banner reappears.
  /// Call this whenever the Home screen becomes visible (tab switch,
  /// app resume, navigation back).
  void resetDismiss() {
    hiddenLocally.value = false;
  }

  /// Hide the banner until the next Home screen visit.
  void dismiss() {
    hiddenLocally.value = true;
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

  /// Current offer model (may be null).
  OfferModel? get offer => result.value?.offer;
}
