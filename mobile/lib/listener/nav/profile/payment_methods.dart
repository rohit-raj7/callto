import 'package:flutter/material.dart';
import '../../../services/call_service.dart';
import '../../../models/call_model.dart';

/// ============================================
/// EARNINGS CALCULATION CONSTANTS
/// ============================================
/// 
/// Platform commission is NOT calculated on frontend.
/// The backend stores the actual listener payout (listener_earn) per call,
/// computed from the admin-set listener_payout_per_min rate.
/// Platform commission = userCharge - listenerEarn (derived from backend data).
/// ============================================

/// ============================================
/// DATA MODELS FOR EARNINGS
/// ============================================

/// Model to hold earnings summary for a specific user (caller)
class UserEarningsSummary {
  final String callerId;
  final String? callerName;
  final String? callerAvatar;
  final int totalCalls;
  final int totalDurationSeconds;
  final double totalEarnings;

  UserEarningsSummary({
    required this.callerId,
    this.callerName,
    this.callerAvatar,
    required this.totalCalls,
    required this.totalDurationSeconds,
    required this.totalEarnings,
  });

  /// Get formatted duration in minutes
  String get formattedDuration {
    final minutes = totalDurationSeconds ~/ 60;
    return '$minutes min';
  }

  /// Get formatted earnings with rupee symbol
  String get formattedEarnings => '₹${totalEarnings.toStringAsFixed(2)}';
}

/// Model to hold weekly earnings summary
class WeeklyEarningsSummary {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int totalCalls;
  final int totalDurationSeconds;
  final double grossEarnings;
  final double platformFee;
  final double netEarnings;

  WeeklyEarningsSummary({
    required this.weekStart,
    required this.weekEnd,
    required this.totalCalls,
    required this.totalDurationSeconds,
    required this.grossEarnings,
    required this.platformFee,
    required this.netEarnings,
  });

  /// Get formatted duration in minutes
  String get formattedDuration {
    final minutes = totalDurationSeconds ~/ 60;
    return '$minutes min';
  }

  /// Get formatted week range
  String get formattedWeekRange {
    final startStr = '${weekStart.day}/${weekStart.month}';
    final endStr = '${weekEnd.day}/${weekEnd.month}';
    return '$startStr - $endStr';
  }
}

/// Model to hold monthly earnings summary
class MonthlyEarningsSummary {
  final int year;
  final int month;
  final int totalCalls;
  final int totalDurationSeconds;
  final double grossEarnings;
  final double platformFee;
  final double netEarnings;

  MonthlyEarningsSummary({
    required this.year,
    required this.month,
    required this.totalCalls,
    required this.totalDurationSeconds,
    required this.grossEarnings,
    required this.platformFee,
    required this.netEarnings,
  });

  /// Get formatted duration in minutes/hours
  String get formattedDuration {
    final totalMinutes = totalDurationSeconds ~/ 60;
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      return '${hours}h ${mins}m';
    }
    return '$totalMinutes min';
  }

  /// Get month name
  String get monthName {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }

  /// Get formatted month-year string
  String get formattedMonthYear => '$monthName $year';
}

/// Model to hold overall earnings breakdown
/// FIX: grossEarnings = total user charge, listenerEarn = backend-calculated
/// payout, platformFee = grossEarnings - listenerEarn. No hardcoded %.
class EarningsBreakdown {
  final double grossEarnings;
  final double platformFee;
  final double netEarnings;

  EarningsBreakdown({
    required this.grossEarnings,
    required this.platformFee,
    required this.netEarnings,
  });
}

/// ============================================
/// EARNINGS CALCULATION SERVICE
/// ============================================
/// 
/// FIX: All earnings are now derived from backend-calculated listener_earn.
/// The admin sets listener_payout_per_min in the DB; the backend computes
/// listenerEarn = callDurationMinutes * listener_payout_per_min and stores
/// it in call_records. The frontend simply reads this value — no
/// hardcoded commission percentages.
/// ============================================
class EarningsCalculator {
  /// Calculate earnings breakdown from call data.
  /// Uses backend-provided listenerEarn (actual payout) and grossEarnings
  /// (user charge). Platform fee = gross - listenerEarn.
  static EarningsBreakdown calculateBreakdownFromBackend(
      double grossEarnings, double listenerEarn) {
    final platformFee = grossEarnings - listenerEarn;
    return EarningsBreakdown(
      grossEarnings: grossEarnings,
      platformFee: platformFee < 0 ? 0 : platformFee,
      netEarnings: listenerEarn,
    );
  }

  /// Group calls by user (caller) and calculate earnings per user
  static List<UserEarningsSummary> groupCallsByUser(List<Call> calls) {
    final Map<String, UserEarningsSummary> userMap = {};

    for (final call in calls) {
      // Only count completed calls with earnings
      if (call.status != 'completed') continue;
      
      final callerId = call.callerId;
      final existing = userMap[callerId];
      
      // FIX: Use call.listenerEarn (backend-calculated payout) instead of
      // call.totalCost (user charge). Falls back to 0 if not yet available.
      final earning = call.listenerEarn ?? 0;
      
      if (existing != null) {
        userMap[callerId] = UserEarningsSummary(
          callerId: callerId,
          callerName: existing.callerName ?? call.callerName,
          callerAvatar: existing.callerAvatar ?? call.callerAvatar,
          totalCalls: existing.totalCalls + 1,
          totalDurationSeconds: existing.totalDurationSeconds + (call.durationSeconds ?? 0),
          totalEarnings: existing.totalEarnings + earning,
        );
      } else {
        userMap[callerId] = UserEarningsSummary(
          callerId: callerId,
          callerName: call.callerName,
          callerAvatar: call.callerAvatar,
          totalCalls: 1,
          totalDurationSeconds: call.durationSeconds ?? 0,
          totalEarnings: earning,
        );
      }
    }

    // Sort by total earnings descending
    final summaries = userMap.values.toList();
    summaries.sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));
    
    return summaries;
  }

  /// Group calls by week (Monday to Sunday) and calculate weekly summaries
  static List<WeeklyEarningsSummary> groupCallsByWeek(List<Call> calls) {
    final Map<DateTime, List<Call>> weekMap = {};

    for (final call in calls) {
      // Only count completed calls
      if (call.status != 'completed') continue;
      
      // Get the call date - use startedAt, endedAt, or createdAt
      final callDate = call.endedAt ?? call.startedAt ?? call.createdAt;
      if (callDate == null) continue;

      // Calculate week start (Monday)
      final weekStart = _getWeekStart(callDate);
      
      if (weekMap.containsKey(weekStart)) {
        weekMap[weekStart]!.add(call);
      } else {
        weekMap[weekStart] = [call];
      }
    }

    // Convert to weekly summaries
    final summaries = <WeeklyEarningsSummary>[];
    
    weekMap.forEach((weekStart, weekCalls) {
      int totalDuration = 0;
      double grossEarnings = 0;
      double listenerEarnings = 0;

      for (final call in weekCalls) {
        totalDuration += call.durationSeconds ?? 0;
        grossEarnings += call.totalCost ?? 0;
        // FIX: Use backend-calculated listenerEarn for actual payout
        listenerEarnings += call.listenerEarn ?? 0;
      }

      // FIX: Use backend values, not hardcoded commission
      final breakdown = calculateBreakdownFromBackend(grossEarnings, listenerEarnings);
      
      summaries.add(WeeklyEarningsSummary(
        weekStart: weekStart,
        weekEnd: weekStart.add(const Duration(days: 6)),
        totalCalls: weekCalls.length,
        totalDurationSeconds: totalDuration,
        grossEarnings: breakdown.grossEarnings,
        platformFee: breakdown.platformFee,
        netEarnings: breakdown.netEarnings,
      ));
    });

    // Sort by week start date descending (most recent first)
    summaries.sort((a, b) => b.weekStart.compareTo(a.weekStart));
    
    return summaries;
  }

  /// Get the start of the week (Monday) for a given date
  static DateTime _getWeekStart(DateTime date) {
    // DateTime.weekday: Monday = 1, Sunday = 7
    final daysToSubtract = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysToSubtract);
  }

  /// Calculate total listener earnings from calls (backend-provided values)
  /// FIX: Use listenerEarn (actual payout) instead of totalCost (user charge).
  static double calculateTotalListenerEarnings(List<Call> calls) {
    double total = 0;
    for (final call in calls) {
      if (call.status == 'completed' && call.listenerEarn != null) {
        total += call.listenerEarn!;
      }
    }
    return total;
  }

  /// Calculate total gross (user charges) from calls
  static double calculateTotalGrossEarnings(List<Call> calls) {
    double total = 0;
    for (final call in calls) {
      if (call.status == 'completed' && call.totalCost != null) {
        total += call.totalCost!;
      }
    }
    return total;
  }

  /// Group calls by month and calculate monthly summaries
  static List<MonthlyEarningsSummary> groupCallsByMonth(List<Call> calls) {
    final Map<String, List<Call>> monthMap = {};

    for (final call in calls) {
      // Only count completed calls
      if (call.status != 'completed') continue;
      
      // Get the call date
      final callDate = call.endedAt ?? call.startedAt ?? call.createdAt;
      if (callDate == null) continue;

      // Create month key (year-month)
      final monthKey = '${callDate.year}-${callDate.month}';
      
      if (monthMap.containsKey(monthKey)) {
        monthMap[monthKey]!.add(call);
      } else {
        monthMap[monthKey] = [call];
      }
    }

    // Convert to monthly summaries
    final summaries = <MonthlyEarningsSummary>[];
    
    monthMap.forEach((monthKey, monthCalls) {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      
      int totalDuration = 0;
      double grossEarnings = 0;
      double listenerEarnings = 0;

      for (final call in monthCalls) {
        totalDuration += call.durationSeconds ?? 0;
        grossEarnings += call.totalCost ?? 0;
        // FIX: Use backend-calculated listenerEarn for actual payout
        listenerEarnings += call.listenerEarn ?? 0;
      }

      // FIX: Use backend values, not hardcoded commission
      final breakdown = calculateBreakdownFromBackend(grossEarnings, listenerEarnings);
      
      summaries.add(MonthlyEarningsSummary(
        year: year,
        month: month,
        totalCalls: monthCalls.length,
        totalDurationSeconds: totalDuration,
        grossEarnings: breakdown.grossEarnings,
        platformFee: breakdown.platformFee,
        netEarnings: breakdown.netEarnings,
      ));
    });

    // Sort by year and month descending (most recent first)
    summaries.sort((a, b) {
      if (a.year != b.year) return b.year.compareTo(a.year);
      return b.month.compareTo(a.month);
    });
    
    return summaries;
  }
}

/// ============================================
/// EARNINGS SCREEN (MAIN WIDGET)
/// ============================================
class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final CallService _callService = CallService();
  
  bool _isLoading = true;
  String? _errorMessage;
  
  List<Call> _allCalls = [];
  List<UserEarningsSummary> _userSummaries = [];
  List<WeeklyEarningsSummary> _weeklySummaries = [];
  List<MonthlyEarningsSummary> _monthlySummaries = [];
  EarningsBreakdown? _totalBreakdown;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadEarningsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load all call history and calculate earnings
  Future<void> _loadEarningsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch listener's call history with high limit to get all calls
      final result = await _callService.getListenerCallHistory(
        limit: 500,
        offset: 0,
      );

      if (result.success) {
        _allCalls = result.calls;
        
        // Calculate all earnings data
        _userSummaries = EarningsCalculator.groupCallsByUser(_allCalls);
        _weeklySummaries = EarningsCalculator.groupCallsByWeek(_allCalls);
        _monthlySummaries = EarningsCalculator.groupCallsByMonth(_allCalls);
        
        // FIX: Use backend-calculated listener earnings, not hardcoded %
        final totalGross = EarningsCalculator.calculateTotalGrossEarnings(_allCalls);
        final totalListenerEarn = EarningsCalculator.calculateTotalListenerEarnings(_allCalls);
        _totalBreakdown = EarningsCalculator.calculateBreakdownFromBackend(
          totalGross, totalListenerEarn,
        );
        
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.error ?? 'Failed to load earnings data';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading earnings: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4EC),
        elevation: 0,
        title: const Text(
          "My Earnings",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.pinkAccent,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.pinkAccent,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : _errorMessage != null
              ? _buildErrorView()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildWeeklyTab(),
                    _buildMonthlyTab(),
                  ],
                ),
    );
  }

  /// Build error view with retry button
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEarningsData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Retry',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Overview tab with total earnings and user breakdown
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadEarningsData,
      color: Colors.pinkAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Earnings Card with Professional Breakdown
            _buildTotalEarningsCard(),
            
            const SizedBox(height: 24),
            
            // Users Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Earnings by User',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${_userSummaries.length} users',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Users List
            _userSummaries.isEmpty
                ? _buildEmptyState('No earnings yet', 'Start taking calls to earn money!')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userSummaries.length,
                    itemBuilder: (context, index) {
                      return _buildUserEarningsCard(_userSummaries[index]);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  /// Build total earnings card with professional breakdown
  Widget _buildTotalEarningsCard() {
    final breakdown = _totalBreakdown ?? EarningsBreakdown(
      grossEarnings: 0,
      platformFee: 0,
      netEarnings: 0,
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.pinkAccent, Color(0xFFFF6B9D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.pinkAccent.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Total Earnings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Net Earnings (Main Amount)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '₹',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                breakdown.netEarnings.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          
          const Text(
            'Total Earnings',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Total Calls & Duration
          Row(
            children: [
              _buildStatPill(
                Icons.call,
                '${_allCalls.where((c) => c.status == 'completed').length} calls',
              ),
              const SizedBox(width: 10),
              _buildStatPill(
                Icons.timer,
                _formatTotalDuration(),
              ),
            ],
          ),
        ],
      ),
    );
  }


  /// Build stat pill widget
  Widget _buildStatPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Format total duration from all completed calls
  String _formatTotalDuration() {
    int totalSeconds = 0;
    for (final call in _allCalls) {
      if (call.status == 'completed' && call.durationSeconds != null) {
        totalSeconds += call.durationSeconds!;
      }
    }
    
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '$minutes min';
  }

  /// Build user earnings card
  Widget _buildUserEarningsCard(UserEarningsSummary summary) {
    // FIX: totalEarnings now already contains the backend-calculated
    // listener payout, so netEarnings = totalEarnings directly.
    final netEarnings = summary.totalEarnings;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE4EC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // User Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFFFE4EC),
              backgroundImage: summary.callerAvatar != null && summary.callerAvatar!.isNotEmpty
                  ? NetworkImage(summary.callerAvatar!)
                  : null,
              child: summary.callerAvatar == null || summary.callerAvatar!.isEmpty
                  ? const Icon(Icons.person, color: Colors.pinkAccent, size: 24)
                  : null,
            ),
            
            const SizedBox(width: 14),
            
            // User Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.callerName ?? 'User ${summary.callerId.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.call, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${summary.totalCalls} calls',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.timer, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        summary.formattedDuration,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Earnings Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${netEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Earned',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build Weekly tab with week-wise earnings
  Widget _buildWeeklyTab() {
    return RefreshIndicator(
      onRefresh: _loadEarningsData,
      color: Colors.pinkAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.pinkAccent, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Weekly summary from Monday to Sunday',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Section Header
            const Text(
              'Weekly Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Weekly Summaries
            _weeklySummaries.isEmpty
                ? _buildEmptyState('No weekly data', 'Complete calls to see weekly summaries!')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _weeklySummaries.length,
                    itemBuilder: (context, index) {
                      return _buildWeeklySummaryCard(_weeklySummaries[index]);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  /// Build weekly summary card with professional earnings
  Widget _buildWeeklySummaryCard(WeeklyEarningsSummary summary) {
    // Check if this is current week
    final now = DateTime.now();
    final currentWeekStart = EarningsCalculator._getWeekStart(now);
    final isCurrentWeek = summary.weekStart.isAtSameMomentAs(currentWeekStart);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentWeek ? Colors.pinkAccent : const Color(0xFFFFE4EC),
          width: isCurrentWeek ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Week Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: isCurrentWeek ? Colors.pinkAccent : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      summary.formattedWeekRange,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isCurrentWeek ? Colors.pinkAccent : Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (isCurrentWeek)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 14),
            
            // Stats Row
            Row(
              children: [
                _buildWeekStatItem(
                  Icons.call,
                  '${summary.totalCalls}',
                  'Calls',
                  Colors.blue,
                ),
                _buildWeekStatItem(
                  Icons.timer,
                  summary.formattedDuration,
                  'Duration',
                  Colors.orange,
                ),
              ],
            ),
            
            const SizedBox(height: 14),
            
            // Total Earnings Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Total Earned',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${summary.netEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build week stat item
  Widget _buildWeekStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  /// Build empty state widget
  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  /// Build Monthly tab with month-wise earnings history
  Widget _buildMonthlyTab() {
    return RefreshIndicator(
      onRefresh: _loadEarningsData,
      color: Colors.pinkAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month, color: Colors.pinkAccent, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Monthly earnings history',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Earnings History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  '${_monthlySummaries.length} months',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Monthly Summaries
            _monthlySummaries.isEmpty
                ? _buildEmptyState('No monthly data', 'Complete calls to see monthly earnings!')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _monthlySummaries.length,
                    itemBuilder: (context, index) {
                      return _buildMonthlySummaryCard(_monthlySummaries[index]);
                    },
                  ),
          ],
        ),
      ),
    );
  }

  /// Build monthly summary card
  Widget _buildMonthlySummaryCard(MonthlyEarningsSummary summary) {
    // Check if this is current month
    final now = DateTime.now();
    final isCurrentMonth = summary.year == now.year && summary.month == now.month;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentMonth ? Colors.pinkAccent : const Color(0xFFFFE4EC),
          width: isCurrentMonth ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 20,
                      color: isCurrentMonth ? Colors.pinkAccent : Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      summary.formattedMonthYear,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCurrentMonth ? Colors.pinkAccent : Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (isCurrentMonth)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 14),
            
            // Stats Row
            Row(
              children: [
                _buildMonthStatItem(
                  Icons.call,
                  '${summary.totalCalls}',
                  'Calls',
                  Colors.blue,
                ),
                _buildMonthStatItem(
                  Icons.timer,
                  summary.formattedDuration,
                  'Duration',
                  Colors.orange,
                ),
              ],
            ),
            
            const SizedBox(height: 14),
            
            // Total Earnings Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Total Earned',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${summary.netEarnings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build month stat item
  Widget _buildMonthStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
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
