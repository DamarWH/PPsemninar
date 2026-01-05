import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RegisterPage extends StatefulWidget {
  static String id = '/register';

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // === REGISTER FUNCTION ===
  Future<void> register() async {
    final String name = nameController.text.trim();
    final String phone = phoneController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text;
    final String confirmPassword = confirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage("Harap isi semua kolom.");
      return;
    }
    if (password != confirmPassword) {
      showMessage("Password tidak cocok.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("https://damargtg.store:3000/api/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          // server expects display_name, email, password
          "display_name": name,
          "email": email,
          "password": password,
          // "phone": phone, // uncomment/add on server side if you store phone
        }),
      );

      setState(() => _isLoading = false);

      final data = jsonDecode(response.body);
      // server returns 201 on create (or 200)
      if (response.statusCode == 201 || response.statusCode == 200) {
        final token = data['token']?.toString() ?? '';
        final user = data['user'] ?? {};
        final userId =
            user['id']?.toString() ??
            user['uid']?.toString() ??
            user['user_id']?.toString() ??
            '';
        final userEmail = user['email']?.toString() ?? '';

        // simpan token & beberapa info user
        final prefs = await SharedPreferences.getInstance();
        if (token.isNotEmpty) await prefs.setString('token', token);
        if (userId.isNotEmpty) await prefs.setString('user_id', userId);
        if (userEmail.isNotEmpty)
          await prefs.setString('user_email', userEmail);
        if (user['display_name'] != null)
          await prefs.setString('user_display_name', user['display_name']);
        if (user['role'] != null)
          await prefs.setString('user_role', user['role']);

        showMessage("Registrasi berhasil!", success: true);
        Future.delayed(Duration(milliseconds: 700), () {
          Navigator.pushReplacementNamed(context, "/home");
        });
      } else {
        // ambil pesan error dari response (server menggunakan 'error' atau 'message')
        final message = data['error'] ?? data['message'] ?? 'Registrasi gagal';
        showMessage(message);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      showMessage("Gagal registrasi: $e");
    }
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
      duration: Duration(seconds: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 100,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Image.asset('asset/icon/batiksekarniti.png', height: 60)],
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_add, size: 80, color: Colors.black),
                    SizedBox(height: 16),
                    Text(
                      'Bergabung dengan Kami',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Buat akun baru untuk memulai berbelanja batik berkualitas',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
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
                    _buildTextField(
                      nameController,
                      "Nama Lengkap",
                      "Masukkan nama lengkap Anda",
                      Icons.person,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      phoneController,
                      "Nomor HP",
                      "Masukkan nomor HP Anda",
                      Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      emailController,
                      "Email",
                      "Masukkan email Anda",
                      Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 16),
                    _buildPasswordField(
                      passwordController,
                      "Password",
                      "Buat password yang kuat",
                      _obscurePassword,
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    SizedBox(height: 16),
                    _buildPasswordField(
                      confirmPasswordController,
                      "Konfirmasi Password",
                      "Ulangi password Anda",
                      _obscureConfirmPassword,
                      () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                    SizedBox(height: 30),

                    _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Daftar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                    SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Sudah punya akun? ",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pushReplacementNamed(context, "/login"),
                          child: Text(
                            "Login",
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

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(icon, color: Colors.black),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.black),
      ),
    );
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String label,
    String hint,
    bool obscureText,
    VoidCallback toggle,
  ) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(Icons.lock, color: Colors.black),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.black),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: Colors.black,
          ),
          onPressed: toggle,
        ),
      ),
    );
  }
}
