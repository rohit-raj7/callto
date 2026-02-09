import 'package:flutter/material.dart';
import '../widgets/expert_card.dart';
import '../widgets/top_bar.dart';
import '../../services/listener_service.dart';
import '../../services/socket_service.dart';
import '../../models/listener_model.dart' as listener_model;
import '../../ui/skeleton_loading_ui/listener_card_skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ListenerService _listenerService = ListenerService();
  
  String? selectedTopic;
  Map<String, bool> listenerOnlineMap = {};
  List<listener_model.Listener> _listeners = [];
  List<listener_model.Listener> _filteredListeners = [];
  bool _isLoading = false;
  String? _error;

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
    selectedTopic = 'All';
    
    // Connect to socket first to get initial presence status
    SocketService().connectListener().then((_) {
      if (mounted) {
        _loadListeners();
      }
    });

    // --- FIX: Listen for real-time status, no default offline ---
    SocketService().listenerStatusStream.listen((map) {
      if (mounted) {
        setState(() {
          listenerOnlineMap = Map.from(map);
          // Re-filter and sort when online status changes
          _filterListeners();
        });
      }
    });
  }

  Future<void> _loadListeners() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all listeners (online and offline) with high limit
      print('[HOME] Fetching listeners...');
      final result = await _listenerService.getListeners(limit: 100);
      print('[HOME] Result success: ${result.success}, count: ${result.listeners.length}');
      
      if (result.success) {
        // Log all fetched listeners for debugging
        for (var listener in result.listeners) {
          print('[HOME] Listener: ${listener.professionalName}, ID: ${listener.listenerId}, userId: ${listener.userId}, isAvailable: ${listener.isAvailable}');
        }
        
        setState(() {
          _listeners = result.listeners;
          _filterListeners();
        });
        print('[HOME] Filtered listeners count: ${_filteredListeners.length}');
      } else {
        print('[HOME] Failed to load listeners: ${result.error}');
        setState(() {
          _error = 'Failed to load listeners';
        });
      }
    } catch (e) {
      print('[HOME] Error loading listeners: $e');
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
      
      if (aOnline && !bOnline) return -1; // a is online, b is offline -> a first
      if (!aOnline && bOnline) return 1;  // a is offline, b is online -> b first
      
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

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TopBar(),

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
                          color: Colors.grey.withOpacity(0.15),
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
                        items: topics.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                      itemBuilder: (context, index) => const ListenerCardSkeleton(),
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
                                onPressed: _loadListeners,
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
                              onRefresh: _loadListeners,
                              child: ListView.builder(
                                itemCount: _filteredListeners.length,
                                itemBuilder: (context, index) {
                                  final listener = _filteredListeners[index];
                                  final isOnline = _isListenerOnline(listener);
                                  return ExpertCard(
                                    name: listener.professionalName ?? 'Unknown',
                                    age: listener.age ?? 20,
                                    city: listener.location,
                                    topic: listener.primarySpecialty,
                                    rate: listener.formattedRate,
                                    rating: listener.rating,
                                    imagePath: listener.avatarUrl ?? 'assets/images/khushi.jpg',
                                    languages: listener.languages,
                                    listenerId: listener.listenerId,
                                    listenerUserId: listener.userId,
                                    isOnline: isOnline,
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
