import 'dart:convert';
import 'package:batiksekarniti/user/transaksi/pembayaran.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ShippingPage extends StatefulWidget {
  final int totalItems;
  final int totalPrice;
  final List<Map<String, dynamic>> cartItems;

  const ShippingPage({
    super.key,
    required this.totalItems,
    required this.totalPrice,
    required this.cartItems,
  });

  @override
  State<ShippingPage> createState() => _ShippingPageState();
}

class _ShippingPageState extends State<ShippingPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingAddress = true;
  String? _userId;
  String? _token;
  String? _userEmail;

  static const String baseUrl = 'https://api.damargtg.store/api/api';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _token = prefs.getString('token');
      _userId =
          prefs.getString('user_id') ??
          prefs.getString('user_email') ??
          prefs.getString('userId');
      _userEmail = prefs.getString('user_email');

      debugPrint('📦 Token: ${_token?.substring(0, 20)}...');
      debugPrint('📦 User ID: $_userId');
      debugPrint('📦 Email: $_userEmail');

      if (_token == null || _token!.isEmpty) {
        throw Exception('Token tidak ditemukan');
      }

      if (_userId == null || _userId!.isEmpty) {
        throw Exception('User ID tidak ditemukan');
      }

      await _loadSavedAddress();
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<void> _loadSavedAddress() async {
    try {
      debugPrint('🔥 Loading address...');

      final uri = Uri.parse('$baseUrl/users/$_userId/shipping');
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('🔥 Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (mounted) {
          setState(() {
            _fullNameController.text = data['fullName'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _addressController.text = data['address'] ?? '';
            _cityController.text = data['city'] ?? '';
            _postalCodeController.text = data['postalCode'] ?? '';
            _notesController.text = data['notes'] ?? '';
          });
        }
        debugPrint('✅ Address loaded');
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No saved address');
      }
    } catch (e) {
      debugPrint('⚠️ Load error: $e');
    }
  }

  Future<void> _saveShippingAddress() async {
    try {
      debugPrint('🔥 Saving address...');

      final shippingData = {
        'fullName': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'postalCode': _postalCodeController.text.trim(),
        'notes': _notesController.text.trim(),
      };

      final uri = Uri.parse('$baseUrl/users/$_userId/shipping');
      final response = await http
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(shippingData),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('🔥 Save response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Address saved');
      }
    } catch (e) {
      debugPrint('⚠️ Save error: $e');
    }
  }

  // 🔥 LANGSUNG KE PEMBAYARAN (tanpa create order dulu)
  void _processCheckout() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // 1. Simpan alamat pengiriman
        await _saveShippingAddress();

        if (!mounted) return;

        // 2. Langsung ke halaman pembayaran
        // Order akan dibuat di PembayaranPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PembayaranPage(
              totalHarga: widget.totalPrice.toDouble(),
              cartItems: widget.cartItems,
              name: _fullNameController.text.trim(),
              email: _userEmail ?? '',
              phone: _phoneController.text.trim(),
              address: _addressController.text.trim(),
              city: _cityController.text.trim(),
              postalCode: _postalCodeController.text.trim(),
              notes: _notesController.text.trim(),
            ),
          ),
        );
      } catch (e) {
        debugPrint('❌ Checkout error: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memproses checkout: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Informasi Pengiriman'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingAddress
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionCard(
                      'Ringkasan Pesanan',
                      Column(
                        children: [
                          _buildSummaryRow(
                            "${widget.totalItems} items",
                            "Rp ${_formatPrice(widget.totalPrice)}",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      'Informasi Pengiriman',
                      Column(
                        children: [
                          _buildTextField(
                            controller: _fullNameController,
                            label: 'Nama Lengkap',
                            icon: Icons.person,
                            validator: (value) => value!.isEmpty
                                ? 'Nama tidak boleh kosong'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _phoneController,
                            label: 'Nomor Telepon',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Nomor telepon tidak boleh kosong';
                              }
                              if (value.length < 10) {
                                return 'Nomor telepon minimal 10 digit';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _addressController,
                            label: 'Alamat Lengkap',
                            icon: Icons.home,
                            maxLines: 3,
                            hintText: 'Jalan, RT/RW, No. Rumah',
                            validator: (value) => value!.isEmpty
                                ? 'Alamat tidak boleh kosong'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _cityController,
                            label: 'Kota/Kabupaten/Kecamatan',
                            icon: Icons.location_city,
                            hintText: 'Contoh: Yogyakarta, Sleman, Depok',
                            validator: (value) => value!.isEmpty
                                ? 'Kota/Kabupaten tidak boleh kosong'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _postalCodeController,
                            label: 'Kode Pos',
                            icon: Icons.markunread_mailbox,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'Kode pos tidak boleh kosong';
                              }
                              if (value.length != 5) {
                                return 'Kode pos harus 5 digit';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _notesController,
                            label: 'Catatan Tambahan (Opsional)',
                            icon: Icons.note,
                            maxLines: 2,
                            hintText: 'Patokan, instruksi khusus, dll.',
                            validator: null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  disabledBackgroundColor: Colors.grey[400],
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text("Memproses..."),
                        ],
                      )
                    : const Text(
                        'Bayar Sekarang',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Card(
      color: Colors.grey[50],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: validator,
    );
  }
}
