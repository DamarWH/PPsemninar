import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  static String id = '/login';

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _showSpinner = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void showMessage(String message, {bool success = false}) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(success ? Icons.check_circle : Icons.error, color: Colors.white),
          SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: success ? Colors.green[700] : Colors.red[700],
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // === LOGIN FUNCTION ===
  Future<void> loginUser() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Email dan password tidak boleh kosong');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      showMessage('Format email tidak valid.');
      return;
    }

    setState(() => _showSpinner = true);

    try {
      final response = await http.post(
        Uri.parse("http://172.20.10.3:3000/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      setState(() => _showSpinner = false);

      if (response.body.isEmpty) {
        showMessage('Response kosong dari server');
        return;
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = (data['token'] ?? '').toString();
        final user = data['user'] ?? {};
        final userId = (user['id'] ?? user['uid'] ?? user['user_id'] ?? '')
            .toString();
        final userEmail = (user['email'] ?? '').toString();
        final roleFromServer = (user['role'] ?? '').toString();

        final prefs = await SharedPreferences.getInstance();
        if (token.isNotEmpty) await prefs.setString('token', token);
        if (userId.isNotEmpty) await prefs.setString('user_id', userId);
        if (userEmail.isNotEmpty)
          await prefs.setString('user_email', userEmail);
        if ((user['display_name'] ?? '') != '') {
          await prefs.setString(
            'user_display_name',
            user['display_name'].toString(),
          );
        }

        // Save role (normalize to lowercase). If server didn't send role, fallback to 'user'
        final normalizedRole = roleFromServer.isNotEmpty
            ? roleFromServer.toLowerCase()
            : 'user';
        await prefs.setString('user_role', normalizedRole);

        showMessage('Login berhasil!', success: true);

        // ✅ PERBAIKAN: SEMUA USER (ADMIN & CUSTOMER) KE /home
        // BottomNavBar akan otomatis mendeteksi role dan menampilkan halaman yang sesuai
        Future.delayed(Duration(milliseconds: 500), () {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, "/home");
        });
      } else {
        final message = data['error'] ?? data['message'] ?? 'Login gagal';
        showMessage(message.toString());
      }
    } catch (e) {
      setState(() => _showSpinner = false);
      showMessage("Gagal login: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        title: Text('Masuk'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Center(
                  child: Image.asset(
                    'asset/icon/batiksekarniti.png',
                    height: 100,
                  ),
                ),
              ),
            ),

            // Form Section
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 20),

                    // Email Field
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Masukkan email Anda',
                        prefixIcon: Icon(Icons.email, color: Colors.black),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Password Field
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Masukkan password Anda',
                        prefixIcon: Icon(Icons.lock, color: Colors.black),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.black, width: 2),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.black,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 30),

                    // Login Button
                    _showSpinner
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: loginUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Masuk',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),

                    SizedBox(height: 20),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Belum punya akun? ",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushNamed(context, '/register'),
                          child: Text(
                            "Daftar",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
