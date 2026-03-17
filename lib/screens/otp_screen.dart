// otp_screen.dart
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'profile_service.dart'; // Import your ProfileService

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  bool _loading = false;
  String? _phone;

  late final AnimationController _animationController;
  late final AnimationController _pulseController;
  late final AnimationController _floatingController;
  late final AnimationController _shakeController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _floatingAnimation;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
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
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _floatingAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_floatingController);
    _shakeAnimation = Tween<double>(
      begin: -5.0,
      end: 5.0,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticInOut,
    ));

    _animationController.forward();
    _pulseController.repeat(reverse: true);
    _floatingController.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the arguments passed from PhoneInputScreen
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is String) {
      _phone = arguments;
    } else {
      _phone = null;
    }
  }

  String? get phone => _phone;

  Future<void> _verifyOtp() async {
    final ph = phone;
    final token = _otpController.text.trim();

    if (ph == null) {
      _showSnackBar('Missing phone argument', isError: true);
      return;
    }

    if (token.length < 6) {
      _shakeController.forward().then((_) => _shakeController.reset());
      _showSnackBar('Enter complete 6-digit OTP', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.sms,
        token: token,
        phone: ph,
      );

      if (res.session != null && res.user != null) {
        // OTP verification successful, now create/update profile
        await _createOrUpdateProfile(ph);

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
        _showSnackBar('Welcome! Verification successful.', isError: false);
      } else {
        if (!mounted) return;
        _shakeController.forward().then((_) => _shakeController.reset());
        _showSnackBar('Verification failed', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _shakeController.forward().then((_) => _shakeController.reset());
      _showSnackBar('Error verifying OTP: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrUpdateProfile(String phone) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if profile already exists
      final existingProfile = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      Map<String, dynamic> profileData = {
        'phone': phone,
      };

      if (existingProfile == null) {
        // Create new profile
        profileData['id'] = user.id;
        await Supabase.instance.client
            .from('profiles')
            .insert(profileData);

        print('Profile created successfully');
      } else {
        // Update existing profile
        await Supabase.instance.client
            .from('profiles')
            .update(profileData)
            .eq('id', user.id);

        print('Profile updated successfully');
      }
    } catch (e) {
      print('Error creating/updating profile: $e');
      // Don't throw here as OTP verification was successful
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFF1E293B)
            : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _floatingController.dispose();
    _shakeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _pulseAnimation, _floatingAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(const Color(0xFF3B82F6), const Color(0xFF1D4ED8),
                          (math.sin(_floatingAnimation.value) + 1) / 2)!,
                      Color.lerp(const Color(0xFF1D4ED8), const Color(0xFF3B82F6),
                          (math.sin(_floatingAnimation.value) + 1) / 2)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.security,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Color.lerp(const Color(0xFF3B82F6), const Color(0xFF1D4ED8),
                            (math.sin(_floatingAnimation.value * 1.5) + 1) / 2)!,
                        Color.lerp(const Color(0xFF1D4ED8), const Color(0xFF3B82F6),
                            (math.sin(_floatingAnimation.value * 1.5) + 1) / 2)!,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'Verify Your Phone',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<int>(
                duration: const Duration(milliseconds: 1500),
                tween: IntTween(begin: 0, end: 30),
                builder: (context, value, child) {
                  const fullText = 'Enter the 6-digit code sent to';
                  final displayText = fullText.substring(0, math.min(value, fullText.length));
                  return Text(
                    displayText,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF94A3B8),
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _floatingAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, math.sin(_floatingAnimation.value * 2) * 2),
                    child: Text(
                      phone ?? '(unknown)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3B82F6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),

            ],
          ),
        );
      },
    );
  }

  Widget _buildOtpCard() {
    return AnimatedBuilder(
      animation: Listenable.merge([_slideAnimation, _shakeAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, _slideAnimation.value * 0.5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _otpController.text.length == 6
                        ? const Color(0xFF3B82F6).withOpacity(0.8)
                        : const Color(0xFF334155).withOpacity(0.5),
                    width: _otpController.text.length == 6 ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.4),
                      blurRadius: 40,
                      offset: const Offset(0, 15),
                    ),
                    if (_otpController.text.length == 6)
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 60,
                        spreadRadius: 5,
                      ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _otpController.text.length == 6
                              ? const Color(0xFF3B82F6).withOpacity(0.8)
                              : const Color(0xFF334155).withOpacity(0.3),
                          width: _otpController.text.length == 6 ? 2 : 1,
                        ),
                        boxShadow: _otpController.text.length == 6 ? [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ] : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 8,
                            ),
                            onChanged: (value) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: '******',
                              hintStyle: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 24,
                                letterSpacing: 8,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF1E293B).withOpacity(0.6),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 20,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: _loading
                              ? null
                              : LinearGradient(
                            colors: [
                              const Color(0xFF3B82F6),
                              const Color(0xFF1D4ED8),
                              const Color(0xFF1E40AF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: _loading
                              ? null
                              : [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withOpacity(0.5),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _loading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _loading
                                ? const Color(0xFF334155)
                                : Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _loading
                              ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Verifying...',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                              : const Text(
                            'Verify & Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
          animation: _floatingAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: math.sin(_floatingAnimation.value * 2 * math.pi) * 0.1,
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
                  'Verification',
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
            animation: _floatingAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5 + math.sin(_floatingAnimation.value) * 0.2,
                    colors: [
                      Color.lerp(const Color(0xFF1E293B), const Color(0xFF0F172A),
                          (math.sin(_floatingAnimation.value) + 1) / 2)!,
                      const Color(0xFF0F172A),
                      const Color(0xFF0A0A0A),
                    ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 40),
                      _buildOtpCard(),
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