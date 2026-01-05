import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _teleponController = TextEditingController();

  // Structured address controllers
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _notesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _postalCodeController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _userId;
  String? _token;

  // Ganti dengan URL backend Anda
  final String baseUrl = 'https://damargtg.store/api';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );

    _animationController.forward();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Try multiple possible token keys
      _token =
          prefs.getString('token') ??
          prefs.getString('auth_token') ??
          prefs.getString('authToken');

      // Try multiple possible user_id keys
      _userId =
          prefs.getString('user_id') ??
          prefs.getString('userId') ??
          prefs.getInt('user_id')?.toString() ??
          prefs.getInt('userId')?.toString();

      debugPrint('=== EDIT PROFILE DEBUG ===');
      debugPrint('🔑 Token exists: ${_token != null}');
      debugPrint('🔑 Token preview: ${_token?.substring(0, 20)}...');
      debugPrint('👤 User ID: $_userId');
      debugPrint('📦 All stored keys: ${prefs.getKeys()}');

      // If no token, redirect to login
      if (_token == null) {
        debugPrint('❌ No token found');
        _showSnackBar('Silakan login terlebih dahulu', Colors.red);
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // If no user_id, try to get it from verify-token
      if (_userId == null) {
        debugPrint('⚠️ No user_id found, trying to verify token...');

        final verifyResponse = await http
            .get(
              Uri.parse('$baseUrl/auth/verify-token'),
              headers: {
                'Authorization': 'Bearer $_token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));

        debugPrint('📊 Verify status: ${verifyResponse.statusCode}');
        debugPrint('📄 Verify body: ${verifyResponse.body}');

        if (verifyResponse.statusCode == 200) {
          final verifyData = json.decode(verifyResponse.body);

          // Try different response structures
          if (verifyData['user'] != null && verifyData['user']['id'] != null) {
            _userId = verifyData['user']['id'].toString();
          } else if (verifyData['id'] != null) {
            _userId = verifyData['id'].toString();
          }

          if (_userId != null) {
            await prefs.setString('user_id', _userId!);
            debugPrint('✅ Got user_id from verify: $_userId');
          }
        } else {
          debugPrint('❌ Verify token failed: ${verifyResponse.statusCode}');
          _showSnackBar('Sesi berakhir, silakan login kembali', Colors.red);
          if (mounted) {
            Navigator.pop(context);
          }
          return;
        }
      }

      // Final check
      if (_userId == null) {
        debugPrint('❌ Still no user_id after verification');
        _showSnackBar('Silakan login ulang', Colors.red);
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      // Fetch user profile
      final profileUrl = '$baseUrl/users/$_userId/profile';
      debugPrint('📡 Fetching profile from: $profileUrl');

      final response = await http
          .get(
            Uri.parse(profileUrl),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📊 Profile status: ${response.statusCode}');
      debugPrint('📄 Profile body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _namaController.text = data['nama'] ?? data['display_name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _teleponController.text = data['telepon'] ?? data['phone'] ?? '';

          // Handle structured shipping address
          if (data['shippingAddress'] != null) {
            final shippingAddress = data['shippingAddress'];
            _addressController.text = shippingAddress['address'] ?? '';
            _cityController.text = shippingAddress['city'] ?? '';
            _fullNameController.text = shippingAddress['fullName'] ?? '';
            _notesController.text = shippingAddress['notes'] ?? '';
            _phoneController.text = shippingAddress['phone'] ?? '';
            _postalCodeController.text = shippingAddress['postalCode'] ?? '';
          }
        });

        debugPrint('✅ Profile loaded successfully');
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('❌ Unauthorized: ${response.statusCode}');
        _showSnackBar('Sesi berakhir, silakan login kembali', Colors.red);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        debugPrint('❌ Failed to load profile: ${response.statusCode}');
        _showSnackBar('Gagal memuat data profil', Colors.red);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading profile: $e');
      debugPrint('Stack trace: $stackTrace');
      _showSnackBar('Gagal memuat data profil: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Prepare shipping address map
      Map<String, dynamic> shippingAddress = {
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'fullName': _fullNameController.text.trim(),
        'notes': _notesController.text.trim(),
        'phone': _phoneController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
      };

      // Prepare request body
      final requestBody = {
        'nama': _namaController.text.trim(),
        'email': _emailController.text.trim(),
        'telepon': _teleponController.text.trim(),
        'shippingAddress': shippingAddress,
      };

      debugPrint('=== SAVE PROFILE DEBUG ===');
      debugPrint('📤 Updating profile for user: $_userId');
      debugPrint('📦 Request body: ${json.encode(requestBody)}');

      // Update user profile
      final updateUrl = '$baseUrl/users/$_userId/profile';
      debugPrint('📡 PUT to: $updateUrl');

      final response = await http
          .put(
            Uri.parse(updateUrl),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: json.encode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📊 Update status: ${response.statusCode}');
      debugPrint('📄 Update body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Update token if changed
        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', data['token']);
          await prefs.setString('auth_token', data['token']);
          debugPrint('✅ Token updated');
        }

        _showSnackBar('Profil berhasil diperbarui!', const Color(0xFF4CAF50));

        // Return to previous page after 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else if (response.statusCode == 409) {
        debugPrint('⚠️ Email conflict');
        _showSnackBar('Email sudah digunakan oleh akun lain', Colors.red);
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        debugPrint('⚠️ Validation error: ${data['error']}');
        _showSnackBar(data['error'] ?? 'Data tidak valid', Colors.red);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('❌ Unauthorized');
        _showSnackBar('Sesi berakhir, silakan login kembali', Colors.red);
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        debugPrint('❌ Update failed: ${response.statusCode}');
        _showSnackBar('Gagal memperbarui profil', Colors.red);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving profile: $e');
      debugPrint('Stack trace: $stackTrace');
      _showSnackBar('Gagal memperbarui profil: $e', Colors.red);
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _namaController.dispose();
    _emailController.dispose();
    _teleponController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _fullNameController.dispose();
    _notesController.dispose();
    _phoneController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        toolbarHeight: 100,
        title: const Text("Edit Profil"),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingView(isTablet)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Padding(
                            padding: EdgeInsets.all(isTablet ? 24 : 16),
                            child: _buildEditForm(context, isTablet),
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

  Widget _buildLoadingView(bool isTablet) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE00000)),
          ),
          const SizedBox(height: 16),
          Text(
            "Memuat data profil...",
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              color: const Color(0xFF2B2B2B).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm(BuildContext context, bool isTablet) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Avatar Section
          Container(
            width: isTablet ? 120 : 100,
            height: isTablet ? 120 : 100,
            decoration: BoxDecoration(
              color: const Color(0xFF2B2B2B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2B2B2B).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.person_rounded,
                size: isTablet ? 60 : 50,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Personal Information Form
          _buildFormCard(
            isTablet: isTablet,
            title: "Informasi Pribadi",
            children: [
              _buildTextFormField(
                controller: _namaController,
                label: 'Nama Lengkap',
                icon: Icons.person_outline_rounded,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama tidak boleh kosong';
                  }
                  if (value.trim().length < 2) {
                    return 'Nama minimal 2 karakter';
                  }
                  return null;
                },
                isTablet: isTablet,
              ),
              const SizedBox(height: 20),
              _buildTextFormField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email tidak boleh kosong';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Format email tidak valid';
                  }
                  return null;
                },
                isTablet: isTablet,
              ),
              const SizedBox(height: 20),
              _buildTextFormField(
                controller: _teleponController,
                label: 'Nomor Telepon',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (value.trim().length < 10) {
                      return 'Nomor telepon minimal 10 digit';
                    }
                    if (!RegExp(r'^[0-9+\-\s]+$').hasMatch(value)) {
                      return 'Format nomor telepon tidak valid';
                    }
                  }
                  return null;
                },
                isTablet: isTablet,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Shipping Address Form
          _buildFormCard(
            isTablet: isTablet,
            title: "Alamat Pengiriman",
            children: [
              _buildTextFormField(
                controller: _fullNameController,
                label: 'Nama Penerima',
                icon: Icons.person_pin_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama penerima tidak boleh kosong';
                  }
                  if (value.trim().length < 2) {
                    return 'Nama penerima minimal 2 karakter';
                  }
                  return null;
                },
                isTablet: isTablet,
              ),
              const SizedBox(height: 20),
              _buildTextFormField(
                controller: _phoneController,
                label: 'Nomor Telepon Penerima',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nomor telepon penerima tidak boleh kosong';
                  }
                  if (value.trim().length < 10) {
                    return 'Nomor telepon minimal 10 digit';
                  }
                  if (!RegExp(r'^[0-9+\-\s]+$').hasMatch(value)) {
                    return 'Format nomor telepon tidak valid';
                  }
                  return null;
                },
                isTablet: isTablet,
              ),
              const SizedBox(height: 20),
              _buildTextFormField(
                controller: _addressController,
                label: 'Alamat Lengkap',
                icon: Icons.location_on_outlined,
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Alamat tidak boleh kosong';
                  }
                  if (value.trim().length < 10) {
                    return 'Alamat minimal 10 karakter';
                  }
                  return null;
                },
                isTablet: isTablet,
              ),
              const SizedBox(height: 20),
              _buildTextFormField(
                controller: _cityController,
                label: 'Kota, Kabupaten, Kecamatan',
                icon: Icons.location_city_outlined,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kota tidak boleh kosong';
                  }
                  if (value.trim().length < 3) {
                    return 'Kota minimal 3 karakter';
                  }
                  return null;
                },
                isTablet: isTablet,
              ),
              const SizedBox(height: 20),
              _buildTextFormField(
                controller: _postalCodeController,
                label: 'Kode Pos',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Kode pos tidak boleh kosong';
                  }
                  if (value.trim().length != 5) {
                    return 'Kode pos harus 5 digit';
                  }
                  if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                    return 'Kode pos hanya boleh berisi angka';
                  }
                  return null;
                },
                isTablet: isTablet,
              ),
              const SizedBox(height: 20),
              _buildTextFormField(
                controller: _notesController,
                label: 'Catatan Alamat (Opsional)',
                icon: Icons.note_outlined,
                maxLines: 2,
                validator: null,
                isTablet: isTablet,
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Save Button
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: _isSaving ? Colors.grey : const Color(0xFFE00000),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (!_isSaving)
                  BoxShadow(
                    color: const Color(0xFFE00000).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isSaving ? null : _saveProfile,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          strokeWidth: 2,
                        ),
                      )
                    else
                      const Icon(
                        Icons.save_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    const SizedBox(width: 12),
                    Text(
                      _isSaving ? "Menyimpan..." : "Simpan Perubahan",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFormCard({
    required bool isTablet,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isTablet,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            color: const Color(0xFF2B2B2B),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: const Color(0xFF2B2B2B).withOpacity(0.5),
              size: isTablet ? 24 : 20,
            ),
            hintText: 'Masukkan $label',
            hintStyle: TextStyle(
              color: const Color(0xFF2B2B2B).withOpacity(0.5),
              fontSize: isTablet ? 16 : 14,
            ),
            filled: true,
            fillColor: const Color(0xFFF5F5DC).withOpacity(0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF2B2B2B).withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFF2B2B2B).withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE00000), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 12,
            ),
          ),
        ),
      ],
    );
  }
}
