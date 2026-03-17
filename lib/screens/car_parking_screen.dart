import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CarParkingScreen extends StatefulWidget {
  const CarParkingScreen({super.key});

  @override
  State<CarParkingScreen> createState() => _CarParkingScreenState();
}

class _CarParkingScreenState extends State<CarParkingScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  // Animation Controllers (matching theme)
  late final AnimationController _animationController;
  late final AnimationController _staggerController;
  late final AnimationController _floatingController;
  late final Animation<double> _fadeAnimation;

  // "My Vehicles" tab state
  final _addVehicleController = TextEditingController();
  bool _isLoadingVehicles = true;
  bool _isAddingVehicle = false;
  List<Map<String, dynamic>> _myVehicles = [];

  // "Report Issue" tab state
  final _reportVehicleController = TextEditingController();
  bool _isReportingVehicle = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Setup animations BEFORE they can be used by any builders
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();
    _staggerController.forward();
    _floatingController.repeat();

    _loadMyVehicles();
  }


  @override
  void dispose() {
    _animationController.dispose();
    _staggerController.dispose();
    _floatingController.dispose();
    _tabController.dispose();
    _addVehicleController.dispose();
    _reportVehicleController.dispose();
    super.dispose();
  }

  Future<void> _loadMyVehicles() async {
    setState(() => _isLoadingVehicles = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('vehicles')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _myVehicles = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load vehicles: $e');
    } finally {
      if (mounted) setState(() => _isLoadingVehicles = false);
    }
  }

  Future<void> _addVehicle() async {
    final plate = _addVehicleController.text.trim().toUpperCase();
    if (plate.isEmpty) return;

    setState(() => _isAddingVehicle = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      await _supabase.from('vehicles').insert({
        'user_id': userId,
        'license_plate': plate,
      });

      _addVehicleController.clear();
      await _loadMyVehicles();
      _showSuccessSnackBar('Vehicle added successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to add vehicle (may already exist)');
    } finally {
      if (mounted) setState(() => _isAddingVehicle = false);
    }
  }

  Future<void> _deleteVehicle(String id) async {
    try {
      await _supabase.from('vehicles').delete().eq('id', id);
      await _loadMyVehicles();
    } catch (e) {
      _showErrorSnackBar('Failed to delete vehicle');
    }
  }

  Future<void> _reportBlockingCar() async {
    final plate = _reportVehicleController.text.trim().toUpperCase();
    if (plate.isEmpty) return;

    setState(() => _isReportingVehicle = true);
    try {
      final vehicleResponse = await _supabase
          .from('vehicles')
          .select('id, user_id')
          .eq('license_plate', plate)
          .maybeSingle();

      if (vehicleResponse == null) {
        _showErrorSnackBar('Vehicle not found in database.');
        return;
      }

      final vehicleId = vehicleResponse['id'];
      final reporterId = _supabase.auth.currentUser?.id;
      
      await _supabase.from('parking_alerts').insert({
        'reporter_id': reporterId,
        'vehicle_id': vehicleId,
        'status': 'pending',
      });

      _reportVehicleController.clear();
      _showSuccessSnackBar('Alert sent to vehicle owner!');
    } catch (e) {
      _showErrorSnackBar('Failed to report vehicle: $e');
    } finally {
      if (mounted) setState(() => _isReportingVehicle = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, int index = 0, EdgeInsetsGeometry? padding}) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, childWidget) {
        final slideValue = Curves.elasticOut.transform(
            (_staggerController.value * 1.5 - index * 0.2).clamp(0.0, 1.0)
        );

        return Transform.translate(
          offset: Offset(0, (1 - slideValue) * 30),
          child: Opacity(
            opacity: slideValue.clamp(0.0, 1.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: padding ?? const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF334155).withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        blurRadius: 40,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) {
            return AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: math.sin(_floatingController.value * 2 * math.pi) * 0.05,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                );
              },
            );
          }
        ),
        title: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _fadeAnimation.value) * 10),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'Car Parking',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3B82F6),
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'My Vehicles', icon: Icon(Icons.directions_car)),
            Tab(text: 'Report Issue', icon: Icon(Icons.warning_amber_rounded)),
          ],
        ),
      ),
      body: Stack(
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
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMyVehiclesTab(),
                  _buildReportIssueTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyVehiclesTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildGlassCard(
            index: 0,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _addVehicleController,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'License Plate (e.g. MH01AB1234)',
                      hintStyle: TextStyle(color: Color(0xFF64748B)),
                      border: InputBorder.none,
                      icon: Icon(Icons.add_card, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
                _isAddingVehicle
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24, height: 24, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6))
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.add_circle, color: Color(0xFF3B82F6), size: 32),
                        onPressed: _addVehicle,
                      ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoadingVehicles
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
                : _myVehicles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_car_filled_outlined, size: 60, color: const Color(0xFF64748B).withOpacity(0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              'No vehicles added yet.\nAdd your vehicle above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _myVehicles.length,
                        itemBuilder: (context, index) {
                          final vehicle = _myVehicles[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildGlassCard(
                              index: index + 1,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.directions_car, color: Color(0xFF3B82F6)),
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        vehicle['license_plate'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => _deleteVehicle(vehicle['id']),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportIssueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, math.sin(_floatingController.value * 2 * math.pi) * 10),
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.2),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ]
                  ),
                  child: const Icon(Icons.car_crash_rounded, size: 80, color: Color(0xFFF59E0B)),
                ),
              );
            }
          ),
          const SizedBox(height: 24),
          _buildGlassCard(
            index: 0,
            child: Column(
              children: [
                const Text(
                  'Is a car blocking your way?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter the license plate of the blocking vehicle. We will send an urgent alert to the owner to move their car immediately.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF334155).withOpacity(0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _reportVehicleController,
                    style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 1.5),
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'e.g. MH01AB1234',
                      hintStyle: TextStyle(color: Color(0xFF64748B), letterSpacing: 0),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildGlassCard(
            index: 1,
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 60,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: _isReportingVehicle
                      ? null
                      : const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: _isReportingVehicle
                      ? null
                      : [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isReportingVehicle ? null : _reportBlockingCar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isReportingVehicle
                        ? const Color(0xFF334155)
                        : Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isReportingVehicle
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFF59E0B)))
                      : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_active, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Alert Owner',
                            style: TextStyle(
                              color: Colors.white, 
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
