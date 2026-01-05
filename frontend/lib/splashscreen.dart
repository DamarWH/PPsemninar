// lib/splashscreen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String verifyUrl =
      "https://damargtg.store/api/auth/verify-token";

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // sedikit delay supaya splash terlihat
    await Future.delayed(const Duration(milliseconds: 600));
    await _checkAuthAndNavigate();
  }

  // debug helper: print semua prefs (panggil saat perlu)
  Future<void> _printPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint(
      'Prefs dump: token=${prefs.getString('token')}, role=${prefs.getString('user_role')}, user_id=${prefs.getString('user_id')}, user_email=${prefs.getString('user_email')}',
    );
  }

  Future<void> _checkAuthAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    String role = (prefs.getString('user_role') ?? 'user').toLowerCase();

    debugPrint(
      'Splash: initial prefs role=$role, token present=${token != null && token.isNotEmpty}',
    );

    // kalau tidak ada token -> langsung ke login
    if (token == null || token.isEmpty) {
      // user guest → boleh lihat produk
      Navigator.pushReplacementNamed(context, "/home");
      return;
    }

    // coba verifikasi token di server (jika server reachable)
    try {
      final resp = await http
          .get(
            Uri.parse(verifyUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 5));

      debugPrint('Splash: verify-token status=${resp.statusCode}');

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        // server expected: { valid: true, user: { role: 'admin', ... } }
        if (body != null && body['valid'] == true && body['user'] != null) {
          final user = body['user'];
          final serverRole = (user['role'] ?? '').toString();
          if (serverRole.isNotEmpty) {
            role = serverRole.toLowerCase();
            await prefs.setString('user_role', role);
            debugPrint('Splash: role from server -> $role (saved)');
          } else {
            // if server didn't send role keep existing (already in role variable)
            await prefs.setString('user_role', role);
            debugPrint('Splash: server returned no role, using prefs -> $role');
          }
        } else {
          // token dianggap tidak valid oleh server -> logout
          debugPrint(
            'Splash: token invalid according to server -> clearing prefs',
          );
          await prefs.remove('token');
          await prefs.remove('user_role');
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, "/login");
          return;
        }
      } else if (resp.statusCode == 401) {
        // unauthorized — token invalid/expired
        debugPrint(
          'Splash: 401 from verify -> clearing token and redirect to login',
        );
        await prefs.remove('token');
        await prefs.remove('user_role');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, "/login");
        return;
      } else {
        // server error or other status — fallback to stored role in prefs
        debugPrint(
          'Splash: verify returned ${resp.statusCode}, will fallback to prefs role',
        );
        role = (prefs.getString('user_role') ?? 'user').toLowerCase();
      }
    } catch (e) {
      // timeout / network error -> fallback ke role di prefs
      debugPrint('Splash: verify-token failed (network/timeout): $e');
      role = (prefs.getString('user_role') ?? 'user').toLowerCase();
    }

    // ensure role is not null
    role = (role).toLowerCase();
    await prefs.setString('user_role', role);

    // optional: print prefs for quick debugging (hapus kalau tidak perlu)
    await _printPrefs();

    // routing akhir
    debugPrint('Splash: final role -> $role, navigating accordingly');
    if (!mounted) return;
    if (role == 'admin') {
      Navigator.pushReplacementNamed(context, "/admin");
    } else {
      Navigator.pushReplacementNamed(context, "/home");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('asset/icon/batiksekarniti.png', height: 120),
            const SizedBox(height: 18),
            const Text(
              'Batik Sekarniti',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(color: Colors.black),
          ],
        ),
      ),
    );
  }
}
