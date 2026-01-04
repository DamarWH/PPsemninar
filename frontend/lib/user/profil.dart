// lib/page/profile/profile.dart - MYSQL BACKEND (FIXED)
import 'dart:convert';
import 'package:batiksekarniti/user/editprofil.dart';
import 'package:batiksekarniti/user/transaksi/transaksi.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // loading / data
  bool _loading = true;
  bool _error = false;
  Map<String, dynamic>? _userData;

  // base url backend
  static const String _baseUrl = 'http://localhost:3000';

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

    _loadProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // responsive helpers
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

  // ------------------- networking -------------------
  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = false;
      _userData = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        setState(() {
          _loading = false;
          _userData = null;
        });
        return;
      }

      // 1️⃣ Verify token → ambil user id
      final verifyResp = await http.get(
        Uri.parse('$_baseUrl/api/auth/verify-token'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (verifyResp.statusCode != 200) {
        throw Exception('Token invalid');
      }

      final verifyData = jsonDecode(verifyResp.body);
      final userId = verifyData['user']?['id'] ?? verifyData['id'];

      if (userId == null) {
        throw Exception('User ID not found');
      }

      // 2️⃣ Ambil profile lengkap (ADA display_name)
      final profileResp = await http.get(
        Uri.parse('$_baseUrl/api/users/$userId/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (profileResp.statusCode != 200) {
        throw Exception('Failed to load profile');
      }

      final profileData = jsonDecode(profileResp.body);

      setState(() {
        _userData = profileData;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading profile: $e');
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<Map<String, dynamic>?> _fetchUserFromServer(String token) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/verify-token');
      debugPrint('📡 Fetching user from: $uri');

      final resp = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📊 Response status: ${resp.statusCode}');
      debugPrint('📄 Response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);

        if (body is Map) {
          // Case 1: { valid: true, user: {...} }
          if (body['user'] != null && body['user'] is Map) {
            final userData = Map<String, dynamic>.from(body['user']);
            debugPrint('✅ User data loaded: ${userData['email']}');
            return userData;
          }
          // Case 2: Direct user object { id, email, display_name, ... }
          else if (body.containsKey('id') || body.containsKey('email')) {
            debugPrint('✅ User data loaded: ${body['email']}');
            return Map<String, dynamic>.from(body);
          }
        }
      } else if (resp.statusCode == 401) {
        debugPrint('⚠️ Token unauthorized');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching user: $e');
    }
    return null;
  }

  Future<void> _performLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('userId');
    await prefs.remove('user_role');

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ------------------- UI builders -------------------

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: _isMobile(screenWidth) ? 80 : 100,
        title: Text(
          "Profil",
          style: TextStyle(
            fontSize: _isMobile(screenWidth) ? 20 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        actions: [
          if (_userData != null)
            IconButton(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
        ],
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
                          child: _buildContent(context, screenWidth),
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

  Widget _buildContent(BuildContext context, double screenWidth) {
    if (_loading) return _buildLoadingView(screenWidth);
    if (_error) return _buildErrorView(screenWidth);

    // not logged in (guest)
    if (_userData == null) return _buildGuestView(context, screenWidth);

    // logged in: show profile using _userData
    final userData = _userData!;

    // Handle different field names from backend
    final displayName =
        userData['display_name']?.toString() ??
        userData['nama']?.toString() ??
        userData['name']?.toString() ??
        'Pengguna';

    final email = userData['email']?.toString() ?? 'Email tidak tersedia';

    final telepon =
        userData['phone']?.toString() ?? userData['telepon']?.toString() ?? '';

    final alamat =
        userData['address']?.toString() ?? userData['alamat']?.toString() ?? '';

    return Column(
      children: [
        SizedBox(height: _isMobile(screenWidth) ? 20 : 32),
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
              SizedBox(height: _isMobile(screenWidth) ? 16 : 24),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: _getTitleFontSize(screenWidth) - 2,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2B2B2B),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: _isMobile(screenWidth) ? 8 : 12),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isMobile(screenWidth) ? 16 : 20,
                  vertical: _isMobile(screenWidth) ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
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
              if (telepon.isNotEmpty || alamat.isNotEmpty) ...[
                SizedBox(height: _isMobile(screenWidth) ? 16 : 24),
                const Divider(color: Color(0xFFE0E0E0)),
                SizedBox(height: _isMobile(screenWidth) ? 16 : 24),
                if (telepon.isNotEmpty)
                  _buildInfoRow(
                    Icons.phone_outlined,
                    "Telepon",
                    telepon,
                    screenWidth,
                  ),
                if (telepon.isNotEmpty && alamat.isNotEmpty)
                  SizedBox(height: _isMobile(screenWidth) ? 12 : 16),
                if (alamat.isNotEmpty)
                  _buildInfoRow(
                    Icons.location_on_outlined,
                    "Alamat",
                    alamat,
                    screenWidth,
                  ),
              ],
            ],
          ),
        ),
        SizedBox(height: _isMobile(screenWidth) ? 32 : 40),

        // Menu sections
        _buildMenuSection("Akun", [
          _buildMenuItem(
            Icons.edit_rounded,
            "Edit Profil",
            "Ubah informasi personal Anda",
            () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditProfilePage(),
                ),
              );
              if (result == true) {
                await _loadProfile();
              }
            },
            screenWidth,
          ),
        ], screenWidth),
        SizedBox(height: _isMobile(screenWidth) ? 24 : 32),
        _buildMenuSection("Aktivitas", [
          _buildMenuItem(
            Icons.history_rounded,
            "Riwayat Transaksi",
            "Lihat semua pembelian Anda",
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransaksiScreen(),
                ),
              );
            },
            screenWidth,
          ),
        ], screenWidth),
        SizedBox(height: _isMobile(screenWidth) ? 24 : 32),
        _buildMenuSection("Lainnya", [
          _buildMenuItem(
            Icons.info_rounded,
            "Tentang Aplikasi",
            "Informasi aplikasi dan versi",
            () {
              _showAboutDialog(context);
            },
            screenWidth,
          ),
        ], screenWidth),
        SizedBox(height: _isMobile(screenWidth) ? 40 : 48),

        // Logout button
        Container(
          width: double.infinity,
          height: _isMobile(screenWidth) ? 56 : 64,
          constraints: BoxConstraints(
            maxWidth: _isDesktop(screenWidth) ? 400 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFE00000),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
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
        SizedBox(height: _isMobile(screenWidth) ? 32 : 40),
      ],
    );
  }

  // Guest view (if not logged in)
  Widget _buildGuestView(BuildContext context, double screenWidth) {
    return Column(
      children: [
        SizedBox(height: _isMobile(screenWidth) ? 40 : 60),
        Container(
          width: _isMobile(screenWidth)
              ? 150
              : _isTablet(screenWidth)
              ? 200
              : 250,
          height: _isMobile(screenWidth)
              ? 150
              : _isTablet(screenWidth)
              ? 200
              : 250,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2B2B2B).withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Icon(
            Icons.person_outline_rounded,
            size: _isMobile(screenWidth)
                ? 60
                : _isTablet(screenWidth)
                ? 80
                : 100,
            color: const Color(0xFF2B2B2B),
          ),
        ),
        SizedBox(height: _isMobile(screenWidth) ? 32 : 40),
        Text(
          "Bergabunglah dengan Kami!",
          style: TextStyle(
            fontSize: _getTitleFontSize(screenWidth),
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2B2B2B),
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: _isMobile(screenWidth) ? 12 : 16),
        Text(
          "Masuk untuk mengakses fitur lengkap\ndan pengalaman berbelanja yang personal",
          style: TextStyle(
            fontSize: _getSubtitleFontSize(screenWidth),
            color: const Color(0xFF2B2B2B).withOpacity(0.7),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: _isMobile(screenWidth) ? 40 : 48),
        Container(
          width: double.infinity,
          height: _isMobile(screenWidth) ? 56 : 64,
          constraints: BoxConstraints(
            maxWidth: _isDesktop(screenWidth) ? 400 : double.infinity,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFE00000),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE00000).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.pushNamed(context, '/login');
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login_rounded,
                    color: Colors.white,
                    size: _getIconSize(screenWidth),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Masuk / Daftar",
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
        SizedBox(height: _isMobile(screenWidth) ? 24 : 32),
        _isDesktop(screenWidth)
            ? Row(
                children: [
                  Expanded(
                    child: _buildBenefitCard(
                      Icons.shopping_bag_outlined,
                      "Belanja Mudah",
                      "Akses cepat ke produk favorit",
                      screenWidth,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBenefitCard(
                      Icons.history_rounded,
                      "Riwayat Lengkap",
                      "Lacak semua transaksi Anda",
                      screenWidth,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildBenefitCard(
                    Icons.shopping_bag_outlined,
                    "Belanja Mudah",
                    "Akses cepat ke produk favorit",
                    screenWidth,
                  ),
                  const SizedBox(height: 16),
                  _buildBenefitCard(
                    Icons.history_rounded,
                    "Riwayat Lengkap",
                    "Lacak semua transaksi Anda",
                    screenWidth,
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildBenefitCard(
    IconData icon,
    String title,
    String subtitle,
    double screenWidth,
  ) {
    return Container(
      width: _isMobile(screenWidth) ? double.infinity : null,
      padding: EdgeInsets.all(_isMobile(screenWidth) ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCCCCCC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 255, 255, 255),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2B2B2B),
              size: _getIconSize(screenWidth),
            ),
          ),
          SizedBox(height: _isMobile(screenWidth) ? 12 : 16),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: _getBodyFontSize(screenWidth) + 2,
              color: const Color(0xFF2B2B2B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: _getBodyFontSize(screenWidth),
              color: const Color(0xFF2B2B2B).withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    double screenWidth,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: _getIconSize(screenWidth) - 4,
          color: const Color(0xFF2B2B2B).withOpacity(0.6),
        ),
        SizedBox(width: _isMobile(screenWidth) ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: _getBodyFontSize(screenWidth) - 2,
                  color: const Color(0xFF2B2B2B).withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: _getBodyFontSize(screenWidth),
                  color: const Color(0xFF2B2B2B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
          padding: EdgeInsets.all(_isMobile(screenWidth) ? 16 : 20),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF2B2B2B),
                size: _getIconSize(screenWidth),
              ),
              SizedBox(width: _isMobile(screenWidth) ? 16 : 20),
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

  Widget _buildLoadingView(double screenWidth) {
    return Column(
      children: [
        SizedBox(height: _isMobile(screenWidth) ? 40 : 60),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE00000)),
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
          color: const Color(0xFFE00000),
        ),
        SizedBox(height: _isMobile(screenWidth) ? 16 : 24),
        Text(
          "Terjadi kesalahan saat memuat data",
          style: TextStyle(
            fontSize: _getSubtitleFontSize(screenWidth),
            color: const Color(0xFF2B2B2B).withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _loadProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2B2B2B),
            foregroundColor: Colors.white,
          ),
          child: const Text('Coba lagi'),
        ),
      ],
    );
  }

  // Add these methods to your _ProfilePageState class

  void _showLogoutDialog(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: const Color(0xFFE00000),
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
            'Apakah Anda yakin ingin keluar dari akun?',
            style: TextStyle(
              fontSize: _getBodyFontSize(screenWidth) + 2,
              color: const Color(0xFF2B2B2B),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: TextStyle(
                  color: const Color(0xFF2B2B2B),
                  fontSize: _getBodyFontSize(screenWidth) + 2,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE00000),
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
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.info_rounded,
                color: const Color(0xFF2B2B2B),
                size: _getIconSize(screenWidth),
              ),
              const SizedBox(width: 8),
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
                'Batik Sekar Niti',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _getBodyFontSize(screenWidth) + 4,
                  color: const Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Versi 1.0.0',
                style: TextStyle(
                  fontSize: _getBodyFontSize(screenWidth),
                  color: const Color(0xFF2B2B2B).withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Aplikasi e-commerce batik terpercaya berbasis Flutter. Temukan koleksi batik terbaik dengan kualitas premium.',
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
              onPressed: () => Navigator.pop(ctx),
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
