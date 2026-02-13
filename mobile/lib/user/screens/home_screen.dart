import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/expert_card.dart';
import '../widgets/offer_banner.dart';
import '../widgets/top_bar.dart';
import '../../services/call_service.dart';
import '../../services/listener_service.dart';
import '../../services/offer_banner_controller.dart';
import '../../services/socket_service.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../models/listener_model.dart' as listener_model;
import '../../models/user_model.dart';
import '../../ui/skeleton_loading_ui/listener_card_skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ListenerService _listenerService = ListenerService();
  final CallService _callService = CallService();
  final StorageService _storageService = StorageService();
  final UserService _userService = UserService();
  final OfferBannerController _offerCtrl = OfferBannerController();

  String? selectedTopic;
  Map<String, bool> listenerOnlineMap = {};
  Map<String, bool> listenerBusyMap = {};
  List<listener_model.Listener> _listeners = [];
  List<listener_model.Listener> _filteredListeners = [];
  bool _isLoading = false;
  String? _error;
  RateConfig? _rateConfig;
  bool _isFirstTimeEligible = false;
  bool _hasCompletedOfferCall = false;
  int? _offerMinutesLimitOverride;

  // Stream subscriptions for cleanup
  StreamSubscription<Map<String, bool>>? _onlineStatusSub;
  StreamSubscription<Map<String, bool>>? _busyStatusSub;

  final List<String> topics = [
    'All',
    'Confidence',
    'Marriage',
    'Breakup',
    'Single',
    'Relationship',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    selectedTopic = 'All';

    _loadOfferEligibility();
    _loadRateConfig();

    // Show offer banner (reset dismiss + load cached + sync API)
    _offerCtrl.resetDismiss();
    _offerCtrl.refresh();
    // Listen for state changes so we rebuild when banner data arrives
    _offerCtrl.result.addListener(_onOfferChanged);
    _offerCtrl.hiddenLocally.addListener(_onOfferChanged);

    // Connect to socket first to get initial presence status
    SocketService().connectListener().then((_) {
      if (mounted) {
        _loadListeners();
      }
    });

    // --- FIX: Listen for real-time status, no default offline ---
    _onlineStatusSub = SocketService().listenerStatusStream.listen((map) {
      if (mounted) {
        setState(() {
          listenerOnlineMap = Map.from(map);
          // Re-filter and sort when online status changes
          _filterListeners();
        });
      }
    });

    // Listen for real-time busy status updates
    _busyStatusSub = SocketService().listenerBusyStream.listen((map) {
      if (mounted) {
        setState(() {
          listenerBusyMap = Map.from(map);
          // Re-filter/sort when busy status changes
          _filterListeners();
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineStatusSub?.cancel();
    _busyStatusSub?.cancel();
    _offerCtrl.result.removeListener(_onOfferChanged);
    _offerCtrl.hiddenLocally.removeListener(_onOfferChanged);
    super.dispose();
  }

  void _onOfferChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Banner reappears every time the user returns to the app
      _offerCtrl.resetDismiss();
      _offerCtrl.refresh();
    }
  }

  Future<void> _loadOfferEligibility() async {
    // 1) Try fetching fresh profile from backend (updates local storage too)
    try {
      final result = await _userService.getProfile();
      if (result.success && result.user != null) {
        if (mounted) {
          setState(() {
            _isFirstTimeEligible =
                result.user!.isFirstTimeUser && !result.user!.offerUsed;
            _offerMinutesLimitOverride = result.user!.offerMinutesLimit;
          });
        }
        await _refreshOfferEligibilityFromCallHistory();
        return;
      }
    } catch (_) {
      // Backend unreachable - fall back to cached data below
    }

    // 2) Fallback: read from local storage cache
    try {
      final rawUser = await _storageService.getUserData();
      if (rawUser == null) return;
      final decoded = jsonDecode(rawUser);
      Map<String, dynamic>? payload;
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      } else if (decoded is Map) {
        payload = decoded.map((key, value) => MapEntry(key.toString(), value));
      }
      if (payload == null) return;
      final user = User.fromJson(payload);
      if (mounted) {
        setState(() {
          _isFirstTimeEligible = user.isFirstTimeUser && !user.offerUsed;
          _offerMinutesLimitOverride = user.offerMinutesLimit;
        });
      }
      await _refreshOfferEligibilityFromCallHistory();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFirstTimeEligible = false;
        });
      }
    }
  }

  Future<void> _loadRateConfig() async {
    try {
      final result = await _callService.getCallRates();
      if (result.success && result.rateConfig != null) {
        await _storageService.saveCallRateConfig(result.rateConfig!.toJson());
        if (mounted) {
          setState(() {
            _rateConfig = result.rateConfig;
          });
        }
        await _refreshOfferEligibilityFromCallHistory();
        return;
      }
    } catch (e) {
      // Fall back to cached config below.
    }

    final cached = await _storageService.getCallRateConfig();
    if (cached != null && mounted) {
      setState(() {
        _rateConfig = RateConfig.fromJson(cached);
      });
      await _refreshOfferEligibilityFromCallHistory();
    }
  }

  Future<void> _refreshOfferEligibilityFromCallHistory() async {
    if (!mounted || !_isFirstTimeEligible || _hasCompletedOfferCall) return;

    final offerMinutesLimit =
        _rateConfig?.offerMinutesLimit ?? _offerMinutesLimitOverride;

    try {
      final result = await _callService.getCallHistory(limit: 100);
      if (!result.success) return;

      bool hasCompletedOfferCall;
      if (offerMinutesLimit != null && offerMinutesLimit > 0) {
        hasCompletedOfferCall = result.calls.any((call) {
          if (call.status != 'completed') return false;
          final durationSeconds = call.durationSeconds ?? 0;
          if (durationSeconds <= 0) return false;
          final billedMinutes = _billableMinutesFromSeconds(durationSeconds);
          return billedMinutes >= offerMinutesLimit;
        });
      } else {
        hasCompletedOfferCall = result.calls.any(
          (call) => call.status == 'completed',
        );
      }

      if (hasCompletedOfferCall && mounted) {
        setState(() {
          _hasCompletedOfferCall = true;
        });
      }
    } catch (_) {
      // Ignore call history failures and keep current eligibility.
    }
  }

  int _billableMinutesFromSeconds(int durationSeconds) {
    if (durationSeconds <= 0) return 0;
    return (durationSeconds / 60).ceil();
  }

  Future<void> _loadListeners() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all Experts (online and offline) with high limit
      print('[HOME] Fetching Experts...');
      final result = await _listenerService.getListeners(limit: 100);
      print(
        '[HOME] Result success: ${result.success}, count: ${result.listeners.length}',
      );

      if (result.success) {
        // Log all fetched Experts for debugging
        for (var listener in result.listeners) {
          print(
            '[HOME] Listener: ${listener.professionalName}, ID: ${listener.listenerId}, userId: ${listener.userId}, isAvailable: ${listener.isAvailable}',
          );
        }

        setState(() {
          _listeners = result.listeners;
          _filterListeners();
        });
        print('[HOME] Filtered Experts count: ${_filteredListeners.length}');
      } else {
        print('[HOME] Failed to load Experts: ${result.error}');
        setState(() {
          _error = 'Failed to load Experts';
        });
      }
    } catch (e) {
      print('[HOME] Error loading Experts: $e');
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshHomeData() async {
    await Future.wait([_loadListeners(), _offerCtrl.refresh()]);
  }

  void _dismissOfferBanner() {
    _offerCtrl.dismiss();
  }

  void _filterByTopic(String? topic) {
    setState(() {
      selectedTopic = topic;
      _filterListeners();
    });
  }

  void _filterListeners() {
    List<listener_model.Listener> filtered;

    if (selectedTopic == 'All') {
      filtered = List.from(_listeners);
    } else {
      filtered = _listeners.where((listener_model.Listener listener) {
        return listener.specialties.contains(selectedTopic);
      }).toList();
    }

    // Sort by online status: online listeners first, then by rating
    filtered.sort((a, b) {
      final aOnline = _isListenerOnline(a);
      final bOnline = _isListenerOnline(b);

      if (aOnline && !bOnline) {
        return -1; // a is online, b is offline -> a first
      }
      if (!aOnline && bOnline) {
        return 1; // a is offline, b is online -> b first
      }

      // Both same status, sort by rating
      return b.rating.compareTo(a.rating);
    });

    _filteredListeners = filtered;
  }

  /// Check if a listener is online using both API data and socket status
  bool _isListenerOnline(listener_model.Listener listener) {
    // Check socket map first (real-time status)
    final userId = listener.userId;
    final listenerId = listener.listenerId;

    if (listenerOnlineMap.containsKey(userId)) {
      return listenerOnlineMap[userId]!;
    }
    if (listenerOnlineMap.containsKey(listenerId)) {
      return listenerOnlineMap[listenerId]!;
    }

    // Fall back to API status
    return listener.isOnline;
  }

  /// Check if a listener is busy using both API data and socket status
  bool _isListenerBusy(listener_model.Listener listener) {
    final userId = listener.userId;
    final listenerId = listener.listenerId;

    if (listenerBusyMap.containsKey(userId)) {
      return listenerBusyMap[userId]!;
    }
    if (listenerBusyMap.containsKey(listenerId)) {
      return listenerBusyMap[listenerId]!;
    }

    // Fall back to API status
    return listener.isBusy;
  }

  String _formatOfferAmount(double value) {
    if (value % 1 == 0) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String? _buildOfferRateText() {
    final config = _rateConfig;
    if (config == null ||
        !_isFirstTimeEligible ||
        _hasCompletedOfferCall ||
        !config.firstTimeOfferEnabled) {
      return null;
    }

    final minutes = config.offerMinutesLimit ?? 0;
    final price = config.offerFlatPrice ?? 0;
    if (minutes <= 0 || price <= 0) {
      return null;
    }

    final offerPerMinute = price / minutes;
    return '\u20B9${_formatOfferAmount(offerPerMinute)}/min';
  }

  Widget _buildOfferBannerState() {
    if (!_offerCtrl.shouldShow) {
      return const SizedBox.shrink();
    }

    final offer = _offerCtrl.offer!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: OfferBanner(
        offer: offer,
        onClose: _dismissOfferBanner,
        onExpired: () {
          if (!mounted) return;
          _offerCtrl.hiddenLocally.value = true;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TopBar(),
            if (_offerCtrl.shouldShow)
              Flexible(
                flex: 0,
                child: _buildOfferBannerState(),
              ),
            if (!_offerCtrl.shouldShow) _buildOfferBannerState(),

            // Title + Dropdown Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Start a Conversation...",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Professional Dropdown Button
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4EC),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedTopic,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.pinkAccent,
                          size: 24,
                        ),
                        elevation: 8,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        items: topics.map<DropdownMenuItem<String>>((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                value,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selectedTopic == value
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: selectedTopic == value
                                      ? Colors.pinkAccent
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: _filterByTopic,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Expert List
            Expanded(
              child: _isLoading
                  ? ListView.builder(
                      itemCount: 8,
                      itemBuilder: (context, index) =>
                          const ListenerCardSkeleton(),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _refreshHomeData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _filteredListeners.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No experts found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try selecting a different category',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshHomeData,
                      child: ListView.builder(
                        itemCount: _filteredListeners.length,
                        itemBuilder: (context, index) {
                          final listener = _filteredListeners[index];
                          final isOnline = _isListenerOnline(listener);
                          final isBusy = _isListenerBusy(listener);
                          final offerRateText = _buildOfferRateText();
                          final normalRateText =
                              '\u20B9${listener.ratePerMinute.toStringAsFixed(0)}/min';
                          return ExpertCard(
                            name: listener.professionalName ?? 'Unknown',
                            age: listener.age ?? 20,
                            city: listener.location,
                            topic: listener.primarySpecialty,
                            rate: offerRateText ?? normalRateText,
                            secondaryRate: offerRateText != null
                                ? normalRateText
                                : null,
                            rating: listener.rating,
                            imagePath:
                                listener.avatarUrl ??
                                'assets/images/khushi.jpg',
                            languages: listener.languages,
                            listenerId: listener.listenerId,
                            listenerUserId: listener.userId,
                            isOnline: isOnline,
                            isBusy: isBusy,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
