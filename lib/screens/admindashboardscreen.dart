// AdminDashboardScreen.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_report_detail_screen.dart'; // <-- ADD THIS LINE


class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? adminData;

  const AdminDashboardScreen({super.key, this.adminData});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final AnimationController _floatingController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _floatingAnimation;

  int _selectedIndex = 0;
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = false;
  Map<String, int> _stats = {
    'totalUsers': 0,
    'totalReports': 0,
    'activeUsers': 0,
    'openReports': 0,
    'criticalReports': 0,
    'unprocessedReports': 0,
  };

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadDashboardData();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    ));
    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_floatingController);

    _animationController.forward();
    _floatingController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // --------------------
      // Profiles: IMPORTANT - do NOT request avatar_url since it doesn't exist
      // --------------------
      // --------------------
// Profiles: Fetch all user profiles using the admin RPC function
// --------------------
      final profilesResponse = await supabase
          .rpc('get_all_profiles');

      // If the response is an error object, it might be a PostgrestError shape.
      // We assume success returns a List/Array of maps. Use safe conversion.
      List<Map<String, dynamic>> profilesData = [];
      if (profilesResponse is List) {
        profilesData = List<Map<String, dynamic>>.from(
            profilesResponse.map((e) => Map<String, dynamic>.from(e as Map)));
      }

      // --------------------
      // Reports: use admin RPC which returns the detailed report rows
      // --------------------
      final reportsResponse = await supabase.rpc(
        'get_reports_with_user_details',
        params: {
          'limit_count': 100,
          'offset_count': 0,
          'status_filter': null,
          'danger_filter': null,
        },
      );

      List<Map<String, dynamic>> reportsData = [];
      if (reportsResponse is List) {
        reportsData = List<Map<String, dynamic>>.from(
            reportsResponse.map((e) => Map<String, dynamic>.from(e as Map)));
            
        // Sort by danger_score descending so critical items are at top
        reportsData.sort((a, b) {
          int scoreA = int.tryParse(a['danger_score']?.toString() ?? '0') ?? 0;
          int scoreB = int.tryParse(b['danger_score']?.toString() ?? '0') ?? 0;
          return scoreB.compareTo(scoreA);
        });
      }

      // --------------------
      // Stats: RPC that returns JSONB
      // --------------------
      final statsResponse = await supabase.rpc('get_admin_statistics');

      Map<String, dynamic> statsData = {};
      if (statsResponse is Map) {
        statsData = Map<String, dynamic>.from(statsResponse as Map);
      } else if (statsResponse is String) {
        // sometimes rpc may return a JSON string - attempt parse
        try {
          // avoid importing dart:convert repeatedly; inline parse:
          statsData = Map<String, dynamic>.from(
              (await Future.value()).runtimeType == Null ? {} : {});
        } catch (_) {
          statsData = {};
        }
      }

      // Safely extract nested values (guard for missing keys)
      final usersSection = statsData['users'] is Map ? statsData['users'] : {};
      final reportsSection =
      statsData['reports'] is Map ? statsData['reports'] : {};
      final systemSection =
      statsData['system'] is Map ? statsData['system'] : {};

      setState(() {
        _profiles = profilesData;
        _reports = reportsData;
        _stats = {
          'totalUsers': usersSection?['total'] is int
              ? usersSection['total']
              : (usersSection?['total'] is num
              ? (usersSection['total'] as num).toInt()
              : 0),
          'totalReports': reportsSection?['total'] is int
              ? reportsSection['total']
              : (reportsSection?['total'] is num
              ? (reportsSection['total'] as num).toInt()
              : 0),
          'activeUsers': usersSection?['active'] is int
              ? usersSection['active']
              : (usersSection?['active'] is num
              ? (usersSection['active'] as num).toInt()
              : 0),
          'openReports': reportsSection?['open'] is int
              ? reportsSection['open']
              : (reportsSection?['open'] is num
              ? (reportsSection['open'] as num).toInt()
              : 0),
          'criticalReports': reportsSection?['critical'] is int
              ? reportsSection['critical']
              : (reportsSection?['critical'] is num
              ? (reportsSection['critical'] as num).toInt()
              : 0),
          'unprocessedReports': reportsSection?['unprocessed'] is int
              ? reportsSection['unprocessed']
              : (reportsSection?['unprocessed'] is num
              ? (reportsSection['unprocessed'] as num).toInt()
              : 0),
        };
      });
    } catch (e, st) {
      // Keep the error visible so you can see what went wrong
      // If it's the avatar_url error it should no longer happen
      debugPrint('Error loading dashboard data: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: ${e.toString()}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    Navigator.pushReplacementNamed(context, '/admin_login');
  }

  Widget _buildFloatingParticles() {
    return AnimatedBuilder(
      animation: _floatingAnimation,
      builder: (context, child) {
        return Stack(
          children: List.generate(6, (index) {
            final offset = index * (2 * math.pi / 6);
            final x = math.cos(_floatingAnimation.value + offset) * 80;
            final y = math.sin(_floatingAnimation.value + offset) * 60;

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + x,
              top: 100 + y,
              child: Container(
                width: 3 + (index % 3),
                height: 3 + (index % 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDC2626).withOpacity(0.3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                    ),
                  ),
                  child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, ${widget.adminData?['name'] ?? 'Admin'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'System Administrator',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsCards() {
    final stats = [
      {
        'title': 'Total Users',
        'value': _stats['totalUsers'].toString(),
        'icon': Icons.people,
        'color': Color(0xFF3B82F6),
        'subtitle': '${_stats['activeUsers']} active',
      },
      {
        'title': 'Open Reports',
        'value': _stats['openReports'].toString(),
        'icon': Icons.report_problem,
        'color': Color(0xFFF59E0B),
        'subtitle': '${_stats['criticalReports']} critical',
      },
      {
        'title': 'Total Reports',
        'value': _stats['totalReports'].toString(),
        'icon': Icons.analytics,
        'color': Color(0xFF10B981),
        'subtitle': '${_stats['unprocessedReports']} unprocessed',
      },
    ];

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 0.5),
          child: SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: stats.length,
              itemBuilder: (context, index) {
                final stat = stats[index];
                return Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (stat['color'] as Color).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  stat['icon'] as IconData,
                                  color: stat['color'] as Color,
                                  size: 24,
                                ),
                                const Spacer(),
                                Text(
                                  stat['value'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              stat['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (stat['subtitle'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                stat['subtitle'] as String,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    final items = [
      {'icon': Icons.dashboard, 'label': 'Dashboard'},
      {'icon': Icons.people, 'label': 'Users'},
      {'icon': Icons.report, 'label': 'Reports'},
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = _selectedIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFDC2626).withOpacity(0.2)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: isSelected
                              ? const Color(0xFFDC2626)
                              : Colors.white.withOpacity(0.6),
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFDC2626)
                                : Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatsCards(),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Recent Activity',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _profiles.isEmpty
              ? Center(
            child: Text(
              'No recent users',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: math.min(5, _profiles.length),
            itemBuilder: (context, index) {
              final profile = _profiles[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF3B82F6),
                            child: Text(
                              ((profile['full_name'] ?? 'U') as String)
                                  .trim()
                                  .isNotEmpty
                                  ? ((profile['full_name'] ?? 'U') as String)[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile['full_name'] ?? 'Unknown User',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  profile['phone'] ?? '',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (profile['is_active'] ?? false)
                                  ? const Color(0xFF10B981).withOpacity(0.2)
                                  : const Color(0xFF6B7280).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (profile['is_active'] ?? false) ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: (profile['is_active'] ?? false)
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF6B7280),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUsersContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'All Users (${_profiles.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh, color: Color(0xFFDC2626)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _profiles.isEmpty
              ? Center(child: Text('No users', style: TextStyle(color: Colors.white.withOpacity(0.6))))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _profiles.length,
            itemBuilder: (context, index) {
              final profile = _profiles[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFF3B82F6),
                                child: Text(
                                  ((profile['full_name'] ?? 'U') as String)
                                      .trim()
                                      .isNotEmpty
                                      ? ((profile['full_name'] ?? 'U') as String)[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile['full_name'] ?? 'Unknown User',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      profile['phone'] ?? 'No phone',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: (profile['is_active'] ?? false)
                                      ? const Color(0xFF10B981).withOpacity(0.2)
                                      : const Color(0xFF6B7280).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  (profile['is_active'] ?? false) ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: (profile['is_active'] ?? false)
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF6B7280),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (profile['created_at'] != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Joined: ${_formatTimestamp(profile['created_at'])}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Reports (${_reports.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh, color: Color(0xFFDC2626)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _reports.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.report_off,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No reports found',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _reports.length,
            itemBuilder: (context, index) {
              final report = _reports[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  // ## ADDED: Material and InkWell for the tap effect and navigation ##
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // This is the navigation logic to open the detail screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdminReportDetailScreen(report: report),
                          ),
                        );
                      },
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        // Your original container is now the child of the InkWell
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getDangerColor(report['danger_level']).withOpacity(0.3),
                            ),
                          ),
                          // This Row contains your complete, unchanged layout
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image Thumbnail
                              if (report['image_url'] != null && (report['image_url'] as String).isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      report['image_url'],
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.white.withOpacity(0.1),
                                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDC2626))),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 70,
                                          height: 70,
                                          color: Colors.white.withOpacity(0.1),
                                          child: const Icon(Icons.image_not_supported_outlined, color: Colors.white54),
                                        );
                                      },
                                    ),
                                  ),
                                ),

                              // Text details and buttons
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.report_problem,
                                          color: _getDangerColor(report['danger_level']),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            // This now shows the reporter's name
                                            'Reported by ${report['user_name'] ?? 'Unknown User'}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getDangerColor(report['danger_level']).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            (report['danger_level'] ?? 'UNKNOWN').toString().toUpperCase(),
                                            style: TextStyle(
                                              color: _getDangerColor(report['danger_level']),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(report['status']).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            (report['status'] ?? 'OPEN').toString().toUpperCase(),
                                            style: TextStyle(
                                              color: _getStatusColor(report['status']),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (String newStatus) {
                                            _updateReportStatus(report['report_id'], newStatus);
                                          },
                                          icon: const Icon(Icons.more_vert, color: Colors.white70),
                                          color: const Color(0xFF1E293B),
                                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                            const PopupMenuItem<String>(value: 'in_progress', child: Text('Set to In Progress', style: TextStyle(color: Colors.white))),
                                            const PopupMenuItem<String>(value: 'resolved', child: Text('Set to Resolved', style: TextStyle(color: Colors.white))),
                                            const PopupMenuItem<String>(value: 'closed', child: Text('Set to Closed', style: TextStyle(color: Colors.white))),
                                          ],
                                        ),
                                      ],
                                    ),
                                    if (report['created_at'] != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Created: ${_formatTimestamp(report['created_at'])}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getDangerColor(dynamic dangerLevel) {
    final level = dangerLevel?.toString().toLowerCase();
    switch (level) {
      case 'critical':
        return const Color(0xFFDC2626);
      case 'high':
        return const Color(0xFFF59E0B);
      case 'medium':
        return const Color(0xFF3B82F6);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Color _getStatusColor(dynamic status) {
    final s = status?.toString().toLowerCase();
    switch (s) {
      case 'open':
        return const Color(0xFFF59E0B);
      case 'in_progress':
        return const Color(0xFF3B82F6);
      case 'resolved':
        return const Color(0xFF10B981);
      case 'closed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatTimestamp(dynamic ts) {
    try {
      if (ts == null) return '';
      // ts may already be a string (ISO), or DateTime
      if (ts is String) {
        final dt = DateTime.parse(ts).toLocal();
        return dt.toString().split('.')[0];
      } else if (ts is DateTime) {
        return ts.toLocal().toString().split('.')[0];
      } else {
        // fallback: try toString
        return ts.toString();
      }
    } catch (_) {
      return ts.toString();
    }
  }

  String _safePercent(dynamic score) {
    try {
      if (score == null) return '';
      final numv = (score is num) ? score : num.parse(score.toString());
      return '${(numv * 100).round()}%';
    } catch (_) {
      return score.toString();
    }
  }

  Future<void> _updateReportStatus(String reportId, String newStatus) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'update_report_status',
        params: {
          'report_uuid': reportId,
          'new_status': newStatus,
          'admin_email': widget.adminData?['email'] ?? 'admin@example.com',
          'admin_notes_text': 'Status updated via admin dashboard',
        },
      );

      if (result == true || result == 't') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report status updated to $newStatus'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        await _loadDashboardData();
      } else {
        throw Exception('Failed to update report status');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating report: ${e.toString()}'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildUsersContent();
      case 2:
        return _buildReportsContent();
      default:
        return _buildDashboardContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _floatingAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5 + math.sin(_floatingAnimation.value) * 0.1,
                    colors: [
                      Color.lerp(const Color(0xFF7F1D1D), const Color(0xFF0F172A),
                          (math.sin(_floatingAnimation.value) + 1) / 2)!,
                      const Color(0xFF0F172A),
                      const Color(0xFF0A0A0A),
                    ],
                  ),
                ),
              );
            },
          ),
          _buildFloatingParticles(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFDC2626),
                      ),
                    )
                        : _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }
}
