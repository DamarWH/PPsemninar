// lib/widgets/bottom_navbar.dart
import 'dart:convert';
import 'package:batiksekarniti/admin/dashboard.dart';
import 'package:batiksekarniti/admin/home.dart';
import 'package:batiksekarniti/admin/profil%20admin.dart';
import 'package:batiksekarniti/admin/transaksi.dart';
import 'package:batiksekarniti/user/homepage.dart';
import 'package:batiksekarniti/user/keranjang.dart';
import 'package:batiksekarniti/user/profil.dart';
import 'package:batiksekarniti/user/transaksi/transaksi.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _selectedIndex = 0;
  String _userRole = 'customer';
  bool _isLoading = true;

  static const String BASE_URL = "http://172.20.10.3:3000";

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      debugPrint(
        '🔍 BottomNavBar: Checking role for token: ${token.isNotEmpty ? "present" : "absent"}',
      );

      if (token.isEmpty) {
        debugPrint('⚠️ BottomNavBar: No token found, defaulting to customer');
        _userRole = 'customer';
      } else {
        try {
          // ✅ PERBAIKAN: Endpoint yang benar (tanpa /api)
          final uri = Uri.parse("$BASE_URL/auth/verify-token");
          debugPrint('📡 BottomNavBar: Calling verify-token endpoint: $uri');

          final resp = await http
              .get(
                uri,
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
              )
              .timeout(const Duration(seconds: 6));

          debugPrint(
            '📥 BottomNavBar: verify-token response status=${resp.statusCode}',
          );
          debugPrint(
            '📥 BottomNavBar: verify-token response body=${resp.body}',
          );

          if (resp.statusCode == 200) {
            final body = jsonDecode(resp.body);
            if (body is Map && body['valid'] == true && body['user'] != null) {
              final user = body['user'];
              final role = (user['role'] ?? '').toString().toLowerCase();

              _userRole = role == 'admin' ? 'admin' : 'customer';

              // Simpan role ke prefs untuk konsistensi
              await prefs.setString('user_role', _userRole);

              debugPrint(
                '✅ BottomNavBar: Role detected from server -> $_userRole',
              );
            } else {
              debugPrint(
                '⚠️ BottomNavBar: Invalid response structure, defaulting to customer',
              );
              _userRole = 'customer';
            }
          } else {
            debugPrint(
              '⚠️ BottomNavBar: Non-200 status, defaulting to customer',
            );
            _userRole = 'customer';
          }
        } catch (e) {
          debugPrint('❌ BottomNavBar: Error verifying token: $e');
          // Fallback: cek role dari prefs
          final storedRole = prefs.getString('user_role') ?? 'customer';
          _userRole = storedRole.toLowerCase() == 'admin'
              ? 'admin'
              : 'customer';
          debugPrint(
            '⚠️ BottomNavBar: Using stored role from prefs -> $_userRole',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ BottomNavBar: Fatal error in _getUserRole: $e');
      _userRole = 'customer';
    }

    final itemCount = _getBottomNavItemsForRole(_userRole).length;
    if (_selectedIndex >= itemCount) _selectedIndex = 0;

    debugPrint(
      '🎯 BottomNavBar: Final role = $_userRole, selectedIndex = $_selectedIndex',
    );

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> refreshRole() async {
    await _getUserRole();
  }

  List<Widget> _getPages() {
    if (_userRole == 'admin') {
      return [
        const MonthlyReportPage(), // Dashboard - Laporan Bulanan
        const AdminHomePage(), // Produk
        const AdminTransactionPage(), // Transaksi Admin
        const ProfilePageAdmin(), // Profil Admin
      ];
    } else {
      return [
        const UserHomePage(),
        const CartPage(),
        const TransaksiScreen(),
        const ProfilePage(),
      ];
    }
  }

  List<BottomNavigationBarItem> _getBottomNavItems() {
    return _getBottomNavItemsForRole(_userRole);
  }

  List<BottomNavigationBarItem> _getBottomNavItemsForRole(String role) {
    if (role == 'admin') {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.assessment),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Produk'),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Transaksi',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
        BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart),
          label: 'Keranjang',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long),
          label: 'Transaksi',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
      ];
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
    await prefs.remove('user_role');
    setState(() {
      _userRole = 'customer';
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color.fromARGB(255, 0, 0, 0)),
        ),
      );
    }

    final pages = _getPages();
    final safeIndex = (_selectedIndex < pages.length) ? _selectedIndex : 0;

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: safeIndex,
        backgroundColor: Colors.white,
        selectedItemColor: const Color.fromARGB(255, 0, 0, 0),
        unselectedItemColor: Colors.grey.shade500,
        onTap: _onItemTapped,
        items: _getBottomNavItems(),
        elevation: 8,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
      ),
    );
  }
}
