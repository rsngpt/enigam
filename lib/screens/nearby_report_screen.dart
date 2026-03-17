import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'report_detail_screen.dart'; // import this for navigation

class NearbyReportsScreen extends StatefulWidget {
  const NearbyReportsScreen({super.key});

  @override
  State<NearbyReportsScreen> createState() => _NearbyReportsScreenState();
}

class _NearbyReportsScreenState extends State<NearbyReportsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final AnimationController _floatingController;
  late final Animation<double> _fadeAnimation;

  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  LatLng _center = const LatLng(20.5937, 78.9629); // Default center (India)
  bool _hasUserLocation = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _floatingController = AnimationController(
        duration: const Duration(milliseconds: 3500), vsync: this);

    _fadeAnimation = CurvedAnimation(
        parent: _animationController, curve: Curves.easeInOut);

    _animationController.forward();
    _floatingController.repeat();

    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getUserLocation();
    await _fetchReports();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);
      
      if (mounted) {
        setState(() {
          _center = LatLng(position.latitude, position.longitude);
          _hasUserLocation = true;
        });
        _mapController.move(_center, 13.0);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _fetchReports() async {
    try {
      final response = await Supabase.instance.client
          .from('reports')
          .select()
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      if (mounted) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: const Color(0xFF334155).withOpacity(0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (report['image_url'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    report['image_url'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Report Description',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                report['description'] ?? 'No description provided for this report.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportDetailScreen(report: report),
                      ),
                    );
                  },
                  child: const Text('View Full Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  void _panMap(double dx, double dy) {
    try {
      final camera = _mapController.camera;
      final centerScreenPoint = camera.latLngToScreenPoint(camera.center);
      final newScreenPoint = math.Point(
        centerScreenPoint.x + dx,
        centerScreenPoint.y + dy,
      );
      final newCenter = camera.pointToLatLng(newScreenPoint);
      _mapController.move(newCenter, camera.zoom);
    } catch (e) {
      // Ignored if map not ready
    }
  }

  void _zoomMap(double zoomDelta) {
    try {
      final camera = _mapController.camera;
      _mapController.move(camera.center, camera.zoom + zoomDelta);
    } catch (e) {
      // Ignored if map not ready
    }
  }

  Widget _buildMapControls() {
    return Positioned(
      right: 16,
      bottom: 90, // Positioned safely above the FAB
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Directional Navigation Cross
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF334155).withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildDirectionButton(Icons.keyboard_arrow_up_rounded, () => _panMap(0, -100)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDirectionButton(Icons.keyboard_arrow_left_rounded, () => _panMap(-100, 0)),
                        const SizedBox(width: 44), // Empty space in the middle of the cross
                        _buildDirectionButton(Icons.keyboard_arrow_right_rounded, () => _panMap(100, 0)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildDirectionButton(Icons.keyboard_arrow_down_rounded, () => _panMap(0, 100)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Zoom Controls
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF334155).withOpacity(0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildZoomButton(Icons.add_rounded, () => _zoomMap(1.0)),
                    Container(
                      height: 1.5,
                      width: 44,
                      color: const Color(0xFF334155).withOpacity(0.8),
                    ),
                    _buildZoomButton(Icons.remove_rounded, () => _zoomMap(-1.0)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0xFF3B82F6).withOpacity(0.3),
        highlightColor: const Color(0xFF3B82F6).withOpacity(0.1),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155).withOpacity(0.4)),
          ),
          child: Icon(icon, color: const Color(0xFF94A3B8), size: 30),
        ),
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        splashColor: const Color(0xFF10B981).withOpacity(0.3),
        highlightColor: const Color(0xFF10B981).withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: AnimatedBuilder(
          animation: _floatingController,
          builder: (context, child) {
            return Transform.rotate(
              angle: math.sin(_floatingController.value * 2 * math.pi) * 0.1,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.pop(context),
              ),
            );
          },
        ),
        title: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _fadeAnimation.value) * 10),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'Nearby Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5 + math.sin(_floatingController.value * 2 * math.pi) * 0.2,
                    colors: [
                      Color.lerp(const Color(0xFF1E293B), const Color(0xFF0F172A),
                          (math.sin(_floatingController.value * 2 * math.pi) + 1) / 2)!,
                      const Color(0xFF0F172A),
                      const Color(0xFF0A0A0A),
                    ],
                  ),
                ),
              );
            },
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                  : Stack(
                      children: [
                        FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: 13.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.enigam',
                        ),
                        MarkerLayer(
                          markers: _reports.map((report) {
                            return Marker(
                              point: LatLng(report['latitude'], report['longitude']),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showReportDetails(report),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444).withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.warning_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (_hasUserLocation)
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _center,
                                width: 20,
                                height: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withOpacity(0.5),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    _buildMapControls(),
                  ],
                ),
            ),
          ),
        ],
      ),
      floatingActionButton: FadeTransition(
        opacity: _fadeAnimation,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF0F172A),
          child: const Icon(Icons.my_location, color: Color(0xFF3B82F6)),
          onPressed: _getUserLocation,
        ),
      ),
    );
  }
}