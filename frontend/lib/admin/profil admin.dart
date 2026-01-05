// profile_page_admin.dart - UPDATED WITH MANAGE ADMIN MENU
import 'dart:convert';
import 'package:batiksekarniti/admin/home.dart';
import 'package:batiksekarniti/admin/tambahadmin.dart';
import 'package:batiksekarniti/admin/transaksi.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePageAdmin extends StatefulWidget {
  const ProfilePageAdmin({super.key});

  @override
  State<ProfilePageAdmin> createState() => _ProfilePageAdminState();
}

class _ProfilePageAdminState extends State<ProfilePageAdmin>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _token;

  static const String BASE_URL = "https://damargtg.store:3000";

  @override
  void initState() {
    super.initState();
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
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token') ?? prefs.getString('auth_token');

      if (_token == null || _token!.isEmpty) {
        setState(() {
          _isLoading = false;
          _userData = null;
        });
        return;
      }

      debugPrint('🔍 Fetching admin profile...');
      debugPrint('🔑 Token: ${_token!.substring(0, 20)}...');

      final resp = await http.get(
        Uri.parse('$BASE_URL/api/auth/me'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
        },
      );

      debugPrint('📊 Profile response: ${resp.statusCode}');
      debugPrint('📊 Response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        debugPrint('✅ Profile loaded: ${data['user']}');

        setState(() {
          _userData = data['user'];
          _isLoading = false;
        });
      } else {
        debugPrint('❌ Profile error: ${resp.statusCode} - ${resp.body}');
        setState(() {
          _isLoading = false;
          _userData = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Exception loading profile: $e');
      setState(() {
        _isLoading = false;
        _userData = null;
      });
    }
  }

  // Responsive breakpoints
  bool _isMobile(double width) => width < 768;
  bool _isTablet(double width) => width >= 768 && width < 1024;
  bool _isDesktop(double width) => width >= 1024;

  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (_isMobile(screenWidth)) return const EdgeInsets.all(16);
    if (_isTablet(screenWidth)) return const EdgeInsets.all(20);
    return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
  }

  double _getTitleFontSize(double screenWidth) {
    if (_isMobile(screenWidth)) return 22;
    if (_isTablet(screenWidth)) return 24;
    return 26;
  }

  double _getSubtitleFontSize(double screenWidth) {
    if (_isMobile(screenWidth)) return 16;
    if (_isTablet(screenWidth)) return 17;
    return 18;
  }

  double _getBodyFontSize(double screenWidth) {
    if (_isMobile(screenWidth)) return 14;
    if (_isTablet(screenWidth)) return 15;
    return 16;
  }

  double _getIconSize(double screenWidth) {
    if (_isMobile(screenWidth)) return 24;
    if (_isTablet(screenWidth)) return 26;
    return 28;
  }

  double _getAvatarSize(double screenWidth) {
    if (_isMobile(screenWidth)) return 80;
    if (_isTablet(screenWidth)) return 90;
    return 100;
  }

  BoxConstraints _getContentConstraints(double screenWidth) {
    if (_isMobile(screenWidth)) return const BoxConstraints();
    if (_isTablet(screenWidth)) return const BoxConstraints(maxWidth: 500);
    return const BoxConstraints(maxWidth: 600);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        toolbarHeight: 100,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('asset/icon/batiksekarniti.png', height: 60),
            const SizedBox(width: 10),
            const Text(
              'Admin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: _getContentConstraints(screenWidth),
          child: CustomScrollView(
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
                          padding: _getResponsivePadding(screenWidth),
                          child: _isLoading
                              ? _buildLoadingView(screenWidth)
                              : _userData == null
                              ? _buildErrorView(screenWidth)
                              : _buildUserView(context, screenWidth),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView(double screenWidth) {
    return Column(
      children: [
        SizedBox(height: _isMobile(screenWidth) ? 40 : 60),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
        ),
        SizedBox(height: _isMobile(screenWidth) ? 16 : 24),
        Text(
          "Memuat profil...",
          style: TextStyle(
            fontSize: _getSubtitleFontSize(screenWidth),
            color: const Color(0xFF2B2B2B).withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(double screenWidth) {
    return Column(
      children: [
        SizedBox(height: _isMobile(screenWidth) ? 40 : 60),
        Icon(
          Icons.error_outline_rounded,
          size: _isMobile(screenWidth)
              ? 60
              : _isTablet(screenWidth)
              ? 80
              : 100,
          color: Colors.red,
        ),
        SizedBox(height: _isMobile(screenWidth) ? 16 : 24),
        Text(
          "Gagal memuat profil admin",
          style: TextStyle(
            fontSize: _getSubtitleFontSize(screenWidth),
            color: const Color(0xFF2B2B2B).withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loadUserData,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: const Text('Coba Lagi'),
        ),
      ],
    );
  }

  Widget _buildUserView(BuildContext context, double screenWidth) {
    final nama = _userData!['display_name'] ?? _userData!['name'] ?? "Admin";
    final email = _userData!['email'] ?? "Email tidak tersedia";
    final role = (_userData!['role'] ?? 'admin').toString().toUpperCase();
    final userId = _userData!['id'] ?? 0;

    return Column(
      children: [
        SizedBox(height: _isMobile(screenWidth) ? 20 : 32),

        // Profile Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(_isMobile(screenWidth) ? 24 : 32),
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
            children: [
              // Avatar
              Container(
                width: _getAvatarSize(screenWidth),
                height: _getAvatarSize(screenWidth),
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
                child: Icon(
                  Icons.person_rounded,
                  size: _getAvatarSize(screenWidth) * 0.5,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: _isMobile(screenWidth) ? 16 : 20),

              // Name
              Text(
                nama,
                style: TextStyle(
                  fontSize: _getTitleFontSize(screenWidth) - 2,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2B2B2B),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: _isMobile(screenWidth) ? 8 : 10),

              // Email
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isMobile(screenWidth) ? 16 : 18,
                  vertical: _isMobile(screenWidth) ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  email,
                  style: TextStyle(
                    fontSize: _getBodyFontSize(screenWidth) + 2,
                    color: const Color(0xFF2B2B2B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: _isMobile(screenWidth) ? 12 : 16),

              // Role Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      role,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // User ID
              if (userId > 0) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE0E0E0)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ID: $userId',
                      style: TextStyle(
                        fontSize: _getBodyFontSize(screenWidth) - 2,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        SizedBox(height: _isMobile(screenWidth) ? 28 : 32),

        // Menu Aktivitas
        _buildMenuSection("Aktivitas", [
          _buildMenuItem(
            Icons.receipt_long_rounded,
            "Kelola Transaksi",
            "Lihat dan kelola semua transaksi",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminTransactionPage(),
                ),
              );
            },
            screenWidth,
          ),
          _buildMenuItem(
            Icons.inventory_2_outlined,
            "Kelola Produk",
            "Tambah, edit, dan hapus produk",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminHomePage()),
              );
            },
            screenWidth,
          ),
        ], screenWidth),

        SizedBox(height: _isMobile(screenWidth) ? 20 : 24),

        // ===== MENU MANAJEMEN - BARU DITAMBAHKAN =====
        _buildMenuSection("Manajemen", [
          _buildMenuItem(
            Icons.supervisor_account_rounded,
            "Kelola Admin",
            "Tambah dan hapus akun admin",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageAdminPage(),
                ),
              );
            },
            screenWidth,
          ),
        ], screenWidth),

        SizedBox(height: _isMobile(screenWidth) ? 36 : 40),

        // Logout button
        Container(
          width: double.infinity,
          height: _isMobile(screenWidth) ? 54 : 56,
          constraints: BoxConstraints(
            maxWidth: _isDesktop(screenWidth) ? 360 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _showLogoutDialog(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Colors.white,
                    size: _getIconSize(screenWidth),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Keluar",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _getSubtitleFontSize(screenWidth),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: _isMobile(screenWidth) ? 28 : 32),
      ],
    );
  }

  Widget _buildMenuSection(
    String title,
    List<Widget> items,
    double screenWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            left: 4,
            bottom: _isMobile(screenWidth) ? 12 : 16,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: _getSubtitleFontSize(screenWidth) + 2,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2B2B2B),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    double screenWidth,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(_isMobile(screenWidth) ? 16 : 18),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF2B2B2B),
                size: _getIconSize(screenWidth),
              ),
              SizedBox(width: _isMobile(screenWidth) ? 16 : 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: _getBodyFontSize(screenWidth) + 2,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2B2B2B),
                      ),
                    ),
                    SizedBox(height: _isMobile(screenWidth) ? 4 : 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: _getBodyFontSize(screenWidth) - 1,
                        color: const Color(0xFF2B2B2B).withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: const Color(0xFF2B2B2B).withOpacity(0.4),
                size: _isMobile(screenWidth) ? 16 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Colors.black,
                size: _getIconSize(screenWidth),
              ),
              const SizedBox(width: 8),
              Text(
                'Konfirmasi Keluar',
                style: TextStyle(
                  color: const Color(0xFF2B2B2B),
                  fontSize: _getSubtitleFontSize(screenWidth),
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun admin?',
            style: TextStyle(
              fontSize: _getBodyFontSize(screenWidth) + 2,
              color: const Color(0xFF2B2B2B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: const Color(0xFF2B2B2B).withOpacity(0.7),
                  fontSize: _getBodyFontSize(screenWidth) + 2,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('token');
                await prefs.remove('auth_token');
                await prefs.remove('user_id');
                await prefs.remove('user_role');
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Keluar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getBodyFontSize(screenWidth) + 2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_rounded,
                  color: const Color(0xFF2B2B2B),
                  size: _getIconSize(screenWidth),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Tentang Aplikasi',
                style: TextStyle(
                  color: const Color(0xFF2B2B2B),
                  fontSize: _getSubtitleFontSize(screenWidth),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Batik Sekarniti',
                style: TextStyle(
                  fontSize: _getSubtitleFontSize(screenWidth),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versi 1.0.0',
                style: TextStyle(
                  color: const Color(0xFF2B2B2B).withOpacity(0.7),
                  fontSize: _getBodyFontSize(screenWidth),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Aplikasi e-commerce batik terpercaya dengan backend MySQL. Temukan koleksi batik terbaik dengan kualitas premium.',
                style: TextStyle(
                  height: 1.5,
                  color: const Color(0xFF2B2B2B),
                  fontSize: _getBodyFontSize(screenWidth),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B2B2B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Tutup',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _getBodyFontSize(screenWidth) + 2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
