import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _animationController;
  late final AnimationController _staggerController;
  late final AnimationController _floatingController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  String? _userName;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
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
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
    _staggerController.forward();
    _floatingController.repeat();

    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          _userName = profile['full_name'] as String?;
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _userName = null;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _userName = null;
          _isLoadingProfile = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _staggerController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Widget _buildWelcomeCard() {
    final user = Supabase.instance.client.auth.currentUser;
    final phone = user?.phone ?? 'unknown';
    final id = user?.id ?? 'unknown';

    // Use full name if available, otherwise fallback to phone
    final displayText = _isLoadingProfile
        ? phone
        : _userName ?? phone;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final slideValue = Curves.elasticOut.transform(
            (_staggerController.value * 1.2 - 0.0).clamp(0.0, 1.0)
        );

        return Transform.translate(
          offset: Offset(0, (1 - slideValue) * 30),
          child: Opacity(
            opacity: slideValue.clamp(0.0, 1.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF334155).withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.4),
                        blurRadius: 40,
                        offset: const Offset(0, 15),
                      ),
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        blurRadius: 60,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _floatingController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + math.sin(_floatingController.value * 2 * math.pi) * 0.05,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Color.lerp(const Color(0xFF3B82F6), const Color(0xFF1D4ED8),
                                            (math.sin(_floatingController.value * 2 * math.pi) + 1) / 2)!,
                                        Color.lerp(const Color(0xFF1D4ED8), const Color(0xFF3B82F6),
                                            (math.sin(_floatingController.value * 2 * math.pi) + 1) / 2)!,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3B82F6).withOpacity(0.4),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedBuilder(
                                  animation: _floatingController,
                                  builder: (context, child) {
                                    return ShaderMask(
                                      shaderCallback: (bounds) => LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.white.withOpacity(0.8),
                                          Colors.white,
                                        ],
                                        stops: [
                                          (_floatingController.value - 0.3).clamp(0.0, 1.0),
                                          _floatingController.value.clamp(0.0, 1.0),
                                          (_floatingController.value + 0.3).clamp(0.0, 1.0),
                                        ],
                                      ).createShader(bounds),
                                      child: const Text(
                                        'Welcome back!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  displayText,
                                  style: const TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF334155).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.fingerprint,
                              color: Color(0xFF64748B),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ID: ${id.substring(0, 8)}...',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 14,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
      String title,
      String subtitle,
      IconData icon,
      VoidCallback onTap,
      Color color,
      int index,
      ) {
    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final slideValue = Curves.elasticOut.transform(
            (_staggerController.value * 1.5 - index * 0.2).clamp(0.0, 1.0)
        );

        return Transform.translate(
          offset: Offset(0, (1 - slideValue) * 50),
          child: Opacity(
            opacity: slideValue.clamp(0.0, 1.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: color.withOpacity(0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(20),
                      splashColor: color.withOpacity(0.2),
                      highlightColor: color.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedBuilder(
                              animation: _floatingController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(
                                      0,
                                      math.sin(_floatingController.value * 2 * math.pi + index) * 3
                                  ),
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withOpacity(0.3),
                                          blurRadius: 15,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      icon,
                                      color: color,
                                      size: 24,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
        title: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _fadeAnimation.value) * 20),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            );
          },
        ),
        actions: [
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.rotate(
                angle: math.sin(_floatingController.value * 2 * math.pi) * 0.1,
                child: IconButton(
                  icon: const Icon(Icons.logout, color: Color(0xFF94A3B8)),
                  onPressed: () => _signOut(context),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.5 + math.sin(_floatingController.value * 2 * math.pi) * 0.3,
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
          ...List.generate(8, (index) {
            return AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                final offset = index * (2 * math.pi / 8);
                final x = math.cos(_floatingController.value * 2 * math.pi + offset) * 150;
                final y = math.sin(_floatingController.value * 2 * math.pi + offset) * 100;

                return Positioned(
                  left: MediaQuery.of(context).size.width / 2 + x,
                  top: MediaQuery.of(context).size.height / 4 + y,
                  child: Container(
                    width: 3 + (index % 3),
                    height: 3 + (index % 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    const SizedBox(height: 32),
                    AnimatedBuilder(
                      animation: _staggerController,
                      builder: (context, child) {
                        final slideValue = Curves.easeOut.transform(
                            (_staggerController.value * 1.3 - 0.3).clamp(0.0, 1.0)
                        );

                        return Transform.translate(
                          offset: Offset(0, (1 - slideValue) * 20),
                          child: Opacity(
                            opacity: slideValue,
                            child: const Text(
                              'Quick Actions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 2.5,
                        children: [
                          _buildActionCard(
                            'Create Report',
                            'Submit a new issue',
                            Icons.add_circle_outline,
                                () => Navigator.pushNamed(context, '/report'),
                            const Color(0xFF3B82F6),
                            0,
                          ),
                          _buildActionCard(
                            'My Reports',
                            'View your submissions',
                            Icons.list_alt,
                                () => Navigator.pushNamed(context, '/myreports'),
                            const Color(0xFF10B981),
                            1,
                          ),
                          _buildActionCard(
                            'Nearby Reports',
                            'View area reports',
                            Icons.map_outlined,
                                () => Navigator.pushNamed(context, '/nearby'),
                            const Color(0xFFEF4444),
                            2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}