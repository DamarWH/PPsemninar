// manage_admin_page.dart - FIXED VERSION

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ManageAdminPage extends StatefulWidget {
  const ManageAdminPage({super.key});

  @override
  State<ManageAdminPage> createState() => _ManageAdminPageState();
}

class _ManageAdminPageState extends State<ManageAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _namaController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingList = true;
  bool _obscurePassword = true;
  List<Map<String, dynamic>> _adminList = [];
  String? _token;
  int? _currentUserId;
  String? _loadError;

  static const String BASE_URL = "https://damargtg.store";

  @override
  void initState() {
    super.initState();
    // ✅ PERBAIKAN: Hapus delay dan clearOldTokens
    _loadAdminList();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _namaController.dispose();
    super.dispose();
  }

  // ============================================
  // HELPER: Konversi Int yang Aman
  // ============================================
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // ✅ PERBAIKAN: Fungsi untuk mendapatkan token
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Coba ambil dari 'token' dulu, lalu 'auth_token'
      String? token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        token = prefs.getString('auth_token');
      }

      if (token != null && token.isNotEmpty) {
        debugPrint('✅ Token found: ${token.substring(0, 20)}...');
        return token;
      }

      debugPrint('❌ No token found in SharedPreferences');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting token: $e');
      return null;
    }
  }

  // ✅ PERBAIKAN: Fungsi untuk mendapatkan user ID
  Future<int?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Coba ambil user_id
      final rawUserId = prefs.get('user_id');
      final userId = _parseInt(rawUserId);

      if (userId > 0) {
        debugPrint('✅ User ID found: $userId');
        return userId;
      }

      debugPrint('⚠️ No valid user_id found');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting user ID: $e');
      return null;
    }
  }

  // Responsive breakpoints
  bool _isMobile(double width) => width < 768;
  bool _isTablet(double width) => width >= 768 && width < 1024;

  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (_isMobile(screenWidth)) return const EdgeInsets.all(16);
    if (_isTablet(screenWidth)) return const EdgeInsets.all(20);
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
  }

  double _getTitleFontSize(double screenWidth) {
    if (_isMobile(screenWidth)) return 20;
    if (_isTablet(screenWidth)) return 22;
    return 24;
  }

  double _getBodyFontSize(double screenWidth) {
    if (_isMobile(screenWidth)) return 14;
    if (_isTablet(screenWidth)) return 15;
    return 16;
  }

  BoxConstraints _getContentConstraints(double screenWidth) {
    if (_isMobile(screenWidth)) return const BoxConstraints();
    if (_isTablet(screenWidth)) return const BoxConstraints(maxWidth: 500);
    return const BoxConstraints(maxWidth: 700);
  }

  // ============================================
  // ✅ PERBAIKAN: LOAD ADMIN LIST
  // ============================================
  Future<void> _loadAdminList() async {
    if (!mounted) return;

    setState(() {
      _isLoadingList = true;
      _loadError = null;
    });

    try {
      // Ambil token dan user ID
      _token = await _getToken();
      _currentUserId = await _getUserId();

      debugPrint('🔍 Loading admin list...');
      debugPrint('🔑 Token: ${_token != null ? "Available" : "Missing"}');
      debugPrint('👤 Current user ID: $_currentUserId');

      if (_token == null || _token!.isEmpty) {
        if (mounted) {
          setState(() {
            _loadError = 'Token tidak ditemukan. Silakan login kembali.';
            _isLoadingList = false;
          });

          // Tampilkan dialog dan redirect ke login
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          });
        }
        return;
      }

      final response = await http
          .get(
            Uri.parse('$BASE_URL/api/admin/list'),
            headers: {
              'Authorization': 'Bearer $_token',
              'Accept': 'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout - periksa koneksi server');
            },
          );

      debugPrint('📊 Admin list response: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);

          if (data['admins'] == null) {
            throw Exception('Data admins tidak ditemukan dalam response');
          }

          final List<dynamic> adminsData = data['admins'];
          final List<Map<String, dynamic>> processedAdmins = [];

          for (var admin in adminsData) {
            try {
              final adminId = _parseInt(admin['id']);

              if (adminId == 0) {
                debugPrint('⚠️ Skipping admin with invalid ID');
                continue;
              }

              processedAdmins.add({
                'id': adminId,
                'email': admin['email']?.toString() ?? '',
                'display_name':
                    admin['display_name']?.toString() ?? 'Tidak ada nama',
                'role': admin['role']?.toString() ?? 'admin',
                'created_at': admin['created_at']?.toString() ?? '',
                'is_current_user': admin['is_current_user'] == true,
              });
            } catch (e) {
              debugPrint('⚠️ Error processing admin: $e');
              continue;
            }
          }

          if (mounted) {
            setState(() {
              _adminList = processedAdmins;
              _isLoadingList = false;
            });
            debugPrint('✅ Loaded ${_adminList.length} admin(s)');
          }
        } catch (e) {
          debugPrint('❌ Error parsing response: $e');
          if (mounted) {
            setState(() {
              _loadError = 'Format data tidak valid: ${e.toString()}';
              _isLoadingList = false;
            });
          }
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() {
            _loadError = 'Sesi Anda telah berakhir. Silakan login kembali.';
            _isLoadingList = false;
          });

          // Redirect ke login
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          });
        }
      } else if (response.statusCode == 403) {
        if (mounted) {
          setState(() {
            _loadError = 'Anda tidak memiliki akses admin.';
            _isLoadingList = false;
          });
        }
      } else {
        debugPrint('❌ Failed to load admins: ${response.body}');
        if (mounted) {
          setState(() {
            _loadError = 'Gagal memuat daftar admin (${response.statusCode})';
            _isLoadingList = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception loading admins: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _loadError = 'Terjadi kesalahan: ${e.toString()}';
          _isLoadingList = false;
        });
      }
    }
  }

  Future<void> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      _token = await _getToken();

      if (_token == null || _token!.isEmpty) {
        _showErrorDialog('Token tidak ditemukan. Silakan login kembali.');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('👤 Creating admin: ${_emailController.text}');

      final response = await http.post(
        Uri.parse('$BASE_URL/api/admin/create'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'display_name': _namaController.text.trim(),
        }),
      );

      debugPrint('📊 Create admin response: ${response.statusCode}');

      if (response.statusCode == 201) {
        if (mounted) {
          _showSuccessDialog();
          _clearForm();
          await _loadAdminList();
        }
      } else {
        final error = jsonDecode(response.body);
        if (mounted) {
          _showErrorDialog(error['error'] ?? 'Gagal menambahkan admin');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception adding admin: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        _showErrorDialog('Gagal menambahkan admin: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteAdmin(int adminId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Hapus'),
        content: Text('Apakah Anda yakin ingin menghapus admin: $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE00000),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      _token = await _getToken();

      if (_token == null || _token!.isEmpty) {
        _showErrorDialog('Token tidak ditemukan. Silakan login kembali.');
        return;
      }

      debugPrint('🗑️ Deleting admin ID: $adminId');

      final response = await http.delete(
        Uri.parse('$BASE_URL/api/admin/delete/$adminId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );

      debugPrint('📊 Delete admin response: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadAdminList();
        }
      } else {
        final error = jsonDecode(response.body);
        if (mounted) {
          _showErrorDialog(error['error'] ?? 'Gagal menghapus admin');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception deleting admin: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        _showErrorDialog('Gagal menghapus admin: ${e.toString()}');
      }
    }
  }

  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _namaController.clear();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Berhasil'),
          ],
        ),
        content: const Text('Admin baru berhasil ditambahkan!'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B2B2B),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.error, color: Color(0xFFE00000)),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B2B2B),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        title: Text(
          "Kelola Admin",
          style: TextStyle(
            fontSize: _getTitleFontSize(screenWidth),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: _getContentConstraints(screenWidth),
          child: SingleChildScrollView(
            padding: _getResponsivePadding(screenWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form Tambah Admin
                Container(
                  padding: EdgeInsets.all(_isMobile(screenWidth) ? 20 : 24),
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tambah Admin Baru',
                          style: TextStyle(
                            fontSize: _getTitleFontSize(screenWidth) - 2,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2B2B2B),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _namaController,
                          decoration: InputDecoration(
                            labelText: 'Nama Lengkap',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email tidak boleh kosong';
                            }
                            if (!value.contains('@')) {
                              return 'Email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password tidak boleh kosong';
                            }
                            if (value.length < 6) {
                              return 'Password minimal 6 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _addAdmin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE00000),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : Text(
                                    'Tambah Admin',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize:
                                          _getBodyFontSize(screenWidth) + 2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Daftar Admin
                Text(
                  'Daftar Admin',
                  style: TextStyle(
                    fontSize: _getTitleFontSize(screenWidth) - 2,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2B2B2B),
                  ),
                ),
                const SizedBox(height: 16),

                // Loading or Error State
                if (_isLoadingList)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFE00000),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Memuat daftar admin...',
                            style: TextStyle(
                              fontSize: _getBodyFontSize(screenWidth),
                              color: const Color(0xFF2B2B2B).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_loadError != null)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Color(0xFFE00000),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: _getBodyFontSize(screenWidth),
                              color: const Color(0xFF2B2B2B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadAdminList,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE00000),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_adminList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Color(0xFF2B2B2B),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada admin terdaftar',
                            style: TextStyle(
                              fontSize: _getBodyFontSize(screenWidth),
                              color: const Color(0xFF2B2B2B).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _adminList.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: Color(0xFFE0E0E0)),
                      itemBuilder: (context, index) {
                        final admin = _adminList[index];
                        final isCurrentUser = admin['is_current_user'] == true;

                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: _isMobile(screenWidth) ? 16 : 20,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF2B2B2B),
                            child: Text(
                              (admin['display_name'] ?? 'A')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  admin['display_name'] ??
                                      'Nama tidak tersedia',
                                  style: TextStyle(
                                    fontSize: _getBodyFontSize(screenWidth) + 2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (isCurrentUser) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE00000),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Anda',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize:
                                          _getBodyFontSize(screenWidth) - 2,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            admin['email'] ?? 'Email tidak tersedia',
                            style: TextStyle(
                              fontSize: _getBodyFontSize(screenWidth),
                            ),
                          ),
                          trailing: !isCurrentUser
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFE00000),
                                  ),
                                  onPressed: () => _deleteAdmin(
                                    _parseInt(admin['id']),
                                    admin['email'] ?? '',
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
