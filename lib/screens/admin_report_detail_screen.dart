// admin_report_detail_screen.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class AdminReportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const AdminReportDetailScreen({super.key, required this.report});

  @override
  State<AdminReportDetailScreen> createState() => _AdminReportDetailScreenState();
}

class _AdminReportDetailScreenState extends State<AdminReportDetailScreen> with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final AnimationController _floatingController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Animated Background ---
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5 + math.sin(_floatingController.value * 2 * math.pi) * 0.2,
                    colors: [
                      const Color(0xFF7F1D1D).withOpacity(0.5),
                      const Color(0xFF0F172A),
                      const Color(0xFF0A0A0A),
                    ],
                  ),
                ),
              );
            },
          ),

          // --- Main Content ---
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // --- Custom Header ---
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Image Display ---
                          if (widget.report['image_url'] != null && (widget.report['image_url'] as String).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16.0),
                                child: Image.network(
                                  widget.report['image_url'],
                                  width: double.infinity,
                                  height: 250,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 250,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                    child: const Icon(Icons.broken_image, color: Color(0xFF64748B), size: 50),
                                  ),
                                ),
                              ),
                            ),

                          // --- Description Card ---
                          _buildGlassCard(
                            title: 'Description',
                            child: Text(
                              widget.report['description'] ?? 'No description provided.',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, height: 1.6),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // --- Key Details Card ---
                          _buildGlassCard(
                            title: 'Key Details',
                            child: Column(
                              children: [
                                _buildDetailRow(Icons.person, 'Reported By', widget.report['user_name'] ?? 'Unknown User'),
                                _buildDetailRow(Icons.flag, 'Status', (widget.report['status'] ?? 'OPEN').toUpperCase(),
                                    statusColor: _getStatusColor(widget.report['status'])),
                                _buildDetailRow(Icons.shield, 'Danger Level', (widget.report['danger_level'] ?? 'UNKNOWN').toUpperCase(),
                                    statusColor: _getDangerColor(widget.report['danger_level'])),
                                _buildDetailRow(
                                    Icons.calendar_today, 'Date Reported', _formatTimestamp(widget.report['created_at'])),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable Glass Card Widget ---
  Widget _buildGlassCard({required String title, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  // --- Custom Header Widget ---
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              widget.report['title'] ?? 'Report Details',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 48), // To balance the back button
        ],
      ),
    );
  }

  // Helper widget for displaying rows of details
  Widget _buildDetailRow(IconData icon, String title, String value, {Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF64748B), size: 18),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
          ),
          const Spacer(),
          Container(
            padding: statusColor != null ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : null,
            decoration: statusColor != null
                ? BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            )
                : null,
            child: Text(
              value,
              style: TextStyle(
                  color: statusColor ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Helper functions
  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'N/A';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}, ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts.toString();
    }
  }

  Color _getStatusColor(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'open': return const Color(0xFFF59E0B);
      case 'in_progress': return const Color(0xFF3B82F6);
      case 'resolved': return const Color(0xFF10B981);
      case 'closed': return const Color(0xFF6B7280);
      default: return const Color(0xFF6B7280);
    }
  }

  Color _getDangerColor(dynamic dangerLevel) {
    switch (dangerLevel?.toString().toLowerCase()) {
      case 'critical': return const Color(0xFFDC2626);
      case 'high': return const Color(0xFFF59E0B);
      case 'medium': return const Color(0xFF3B82F6);
      case 'low': return const Color(0xFF10B981);
      default: return const Color(0xFF6B7280);
    }
  }
}