// lib/screens/report_screen.dart
import 'dart:typed_data';
import 'dart:io' show File;
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as p;

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with TickerProviderStateMixin {
  final _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  // Platform-specific image storage
  Uint8List? _webImage;
  File? _imageFile;

  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  static const String BUCKET = 'reports';

  late final AnimationController _animationController;
  late final AnimationController _staggerController;
  late final AnimationController _floatingController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _staggerController.dispose();
    _floatingController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 80,
    );

    if (picked == null) return;

    if (kIsWeb) {
      // On Web: read as bytes
      final bytes = await picked.readAsBytes();
      setState(() {
        _webImage = bytes;
        _imageFile = null; // Clear mobile image
      });
    } else {
      // On Mobile: use File
      setState(() {
        _imageFile = File(picked.path);
        _webImage = null; // Clear web image
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    // Location services check - skip on web if not supported
    if (!kIsWeb) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services.')),
        );
        return;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission permanently denied')),
      );
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }

  Future<String?> _uploadFile(String userId) async {
    final supabase = Supabase.instance.client;
    final extension = kIsWeb && _webImage != null ? '.jpg' :
    _imageFile != null ? p.extension(_imageFile!.path) : '.jpg';
    final safeName = '${userId}/${DateTime.now().millisecondsSinceEpoch}$extension';

    try {
      if (kIsWeb && _webImage != null) {
        // Upload from bytes (Web)
        await supabase.storage.from(BUCKET).uploadBinary(
          safeName,
          _webImage!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
      } else if (!kIsWeb && _imageFile != null) {
        // Upload from file (Mobile)
        await supabase.storage.from(BUCKET).upload(
          safeName,
          _imageFile!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
      } else {
        return null; // No image to upload
      }

      // Get public URL (bucket must be public) OR store the path and generate signed URL server-side if private
      final publicUrl = supabase.storage.from(BUCKET).getPublicUrl(safeName);
      return publicUrl;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _submitReport() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    final hasImage = (kIsWeb && _webImage != null) || (!kIsWeb && _imageFile != null);
    if (!hasImage && _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add description or attach an image')));
      return;
    }

    setState(() => _isLoading = true);

    String? imageUrl;
    String? imagePath;

    try {
      if (hasImage) {
        // Upload image
        final publicUrl = await _uploadFile(user.id);
        if (publicUrl == null) {
          throw Exception('Image upload failed');
        }
        imageUrl = publicUrl;

        // Store imagePath for potential future use
        final extension = kIsWeb ? '.jpg' : p.extension(_imageFile!.path);
        imagePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}$extension';
      }

      // Ensure we have location (optional)
      if (_latitude == null || _longitude == null) {
        // Try to get location quickly (non-blocking)
        await _getCurrentLocation();
      }

      // Insert into 'reports' table
      final insertData = {
        'user_id': user.id,
        'description': _descController.text.trim(),
        'image_path': imagePath,
        'image_url': imageUrl,
        'latitude': _latitude,
        'longitude': _longitude,
      };

      await supabase.from('reports').insert(insertData).select();

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully')));

      // Reset form
      setState(() {
        _webImage = null;
        _imageFile = null;
        _descController.clear();
        _latitude = null;
        _longitude = null;
      });
    } catch (e) {
      debugPrint('Submit error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGlassCard({required Widget child, int index = 0}) {
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
                  padding: const EdgeInsets.all(20),
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

  Widget _imagePreview() {
    Widget imageWidget;

    if (kIsWeb && _webImage != null) {
      imageWidget = Image.memory(
        _webImage!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    } else if (!kIsWeb && _imageFile != null) {
      imageWidget = Image.file(
        _imageFile!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    } else {
      imageWidget = AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, math.sin(_floatingController.value * 2 * math.pi) * 3),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF334155).withOpacity(0.4),
                  style: BorderStyle.solid,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt,
                size: 40,
                color: Color.lerp(const Color(0xFF64748B), const Color(0xFF3B82F6),
                    (math.sin(_floatingController.value * 2 * math.pi) + 1) / 2),
              ),
            ),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageWidget,
    );
  }

  Widget _buildImageSection() {
    return _buildGlassCard(
      index: 0,
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
                  'Attach Image',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _imagePreview(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    if (!kIsWeb)
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.photo_camera, color: Colors.white),
                            label: const Text('Camera', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1D4ED8).withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.photo_library, color: Colors.white),
                          label: const Text('Gallery', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _buildGlassCard(
      index: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _descController.text.isNotEmpty
                    ? const Color(0xFF3B82F6).withOpacity(0.5)
                    : const Color(0xFF334155).withOpacity(0.3),
                width: _descController.text.isNotEmpty ? 2 : 1,
              ),
              boxShadow: _descController.text.isNotEmpty ? [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: TextField(
                  controller: _descController,
                  maxLines: 4,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Describe the issue in detail...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B).withOpacity(0.6),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _buildGlassCard(
      index: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
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
                      AnimatedBuilder(
                        animation: _floatingController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + math.sin(_floatingController.value * 2 * math.pi) * 0.1,
                            child: Icon(
                              _latitude == null || _longitude == null
                                  ? Icons.location_off
                                  : Icons.location_on,
                              color: _latitude == null || _longitude == null
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF3B82F6),
                              size: 20,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _latitude == null || _longitude == null
                              ? 'Location not added'
                              : '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                          style: TextStyle(
                            color: _latitude == null || _longitude == null
                                ? const Color(0xFF64748B)
                                : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.my_location, color: Colors.white),
                  label: const Text('Get Location', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _getCurrentLocation,
                ),
              ),
            ],
          ),
        ],
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
              angle: math.sin(_floatingController.value * 2 * math.pi) * 0.05,
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
                  'Report Issue',
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
          ...List.generate(6, (index) {
            return AnimatedBuilder(
              animation: _floatingController,
              builder: (context, child) {
                final offset = index * (2 * math.pi / 6);
                final x = math.cos(_floatingController.value * 2 * math.pi + offset) * 120;
                final y = math.sin(_floatingController.value * 2 * math.pi + offset) * 80;

                return Positioned(
                  left: MediaQuery.of(context).size.width / 2 + x,
                  top: MediaQuery.of(context).size.height / 4 + y,
                  child: Container(
                    width: 2 + (index % 3),
                    height: 2 + (index % 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.4),
                          blurRadius: 6,
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
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildImageSection(),
                            const SizedBox(height: 20),
                            _buildDescriptionSection(),
                            const SizedBox(height: 20),
                            _buildLocationSection(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: _isLoading
                              ? null
                              : const LinearGradient(
                            colors: [
                              Color(0xFF3B82F6),
                              Color(0xFF1D4ED8),
                              Color(0xFF1E40AF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: _isLoading
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
                          onPressed: _isLoading ? null : _submitReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoading
                                ? const Color(0xFF334155)
                                : Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Submitting...',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                              : const Text(
                            'Submit Report',
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
        ],
      ),
    );
  }
}
