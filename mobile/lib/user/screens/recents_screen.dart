import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/call_service.dart';
import '../../services/storage_service.dart';
import '../../models/call_model.dart';
import '../actions/calling.dart';
import '../actions/charting.dart';
import '../../ui/skeleton_loading_ui/recent_chat_skeleton.dart';

class RecentsScreen extends StatefulWidget {
  const RecentsScreen({super.key});

  @override
  State<RecentsScreen> createState() => _RecentsScreenState();
}

class _RecentsScreenState extends State<RecentsScreen> {
  final CallService _callService = CallService();
  final StorageService _storageService = StorageService();
  
  bool _isLoading = true;
  String? _error;
  List<Call> _callHistory = [];
  String? _currentUserName;
  String? _currentUserAvatar;

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final name = await _storageService.getDisplayName();
    final avatar = await _storageService.getAvatarUrl();
    if (!mounted) return;
    setState(() {
      _currentUserName = name;
      _currentUserAvatar = avatar;
    });
  }

  Future<void> _loadCallHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _callService.getCallHistory(limit: 50);
      
      if (result.success) {
        setState(() {
          _callHistory = result.calls;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result.error;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load call history';
        _isLoading = false;
      });
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final local = dateTime.toLocal();
    return DateFormat('h:mm a').format(local);
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    final local = dateTime.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final callDate = DateTime(local.year, local.month, local.day);

    if (callDate == today) {
      return 'Today';
    } else if (callDate == yesterday) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d, yyyy').format(local);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'missed':
        return 'Missed';
      case 'rejected':
        return 'Declined';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'rejected':
        return Colors.orange;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  int _calculateTotalMinutes(int? durationSeconds) {
    if (durationSeconds == null || durationSeconds <= 0) return 0;
    return (durationSeconds / 60).ceil();
  }

  // Group calls by date
  Map<String, List<Call>> _groupCallsByDate() {
    final Map<String, List<Call>> grouped = {};
    for (final call in _callHistory) {
      final dateKey = _formatDate(call.createdAt);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(call);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFFEEBF1),
              Color(0xFFF7F3FD),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            _buildCustomHeader(context),
            Expanded(
              child: _isLoading
                  ? ListView.builder(
                      itemCount: 10,
                      itemBuilder: (context, index) => const RecentChatSkeleton(),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadCallHistory,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                        : _callHistory.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: _loadCallHistory,
                              child: _buildCallList(),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.call_missed_outgoing, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No recent calls',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallList() {
    final groupedCalls = _groupCallsByDate();
    final dateKeys = groupedCalls.keys.toList();
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: dateKeys.length,
      itemBuilder: (context, index) {
        final dateKey = dateKeys[index];
        final calls = groupedCalls[dateKey]!;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
            ...calls.map((call) => _buildRecentItemCard(call)),
          ],
        );
      },
    );
  }

  Widget _buildCustomHeader(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (canPop)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                const Text(
                  'Recents',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.black54),
              onPressed: _loadCallHistory,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItemCard(Call call) {
    // For user, show listener info (the person they called)
    final name = call.listenerName ?? 'Unknown Listener';
    final avatar = call.listenerAvatar ?? 'https://randomuser.me/api/portraits/lego/1.jpg';
    final status = call.status;
    final isCompleted = status == 'completed';
    final isOnline = call.listenerOnline ?? false;

    const cardGradient = LinearGradient(
      colors: [Color(0xFFFEE9F2), Color(0xFFFBEFFF)],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.pinkAccent.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          children: [
            // Avatar + Status
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: avatar.startsWith('http')
                      ? NetworkImage(avatar)
                      : AssetImage(avatar) as ImageProvider,
                  backgroundColor: Colors.grey.shade200,
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 15),

            // Name and Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${call.formattedDuration} • ${_formatTime(call.createdAt)}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                  if (call.durationSeconds != null && isCompleted)
                    Text(
                      'Total minutes: ${_calculateTotalMinutes(call.durationSeconds)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),

            // Chat and Call Buttons
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 22),
                    onPressed: call.listenerUserId == null
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  expertName: name,
                                  imagePath: avatar,
                                  otherUserId: call.listenerUserId,
                                  otherUserAvatar: call.listenerAvatar,
                                ),
                              ),
                            );
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.pinkAccent, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.call, color: Colors.white, size: 22),
                    onPressed: call.listenerUserId == null
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => Calling(
                                  callerName: name,
                                  callerAvatar: avatar,
                                  userName: _currentUserName ?? 'You',
                                  userAvatar: _currentUserAvatar,
                                  listenerId: call.listenerUserId,
                                  listenerDbId: call.listenerId,
                                ),
                              ),
                            );
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
