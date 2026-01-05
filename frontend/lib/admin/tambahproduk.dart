// lib/admin/tambahproduk.dart - MYSQL BACKEND (FIREBASE STYLE)
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final picker = ImagePicker();
  bool _isLoading = false;
  bool _isSizeLoaded = true;

  final _namaController = TextEditingController();
  final _hargaController = TextEditingController();
  final _warnaController = TextEditingController();
  final _deskripsiController = TextEditingController();
  String? _selectedCategory;

  // Changed to List<dynamic> to support both File (mobile) and Uint8List (web)
  List<dynamic> _pickedImageFiles = [];
  final int _maxImages = 5;

  List<String> _availableSizes = ['S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
  final Map<String, int> _sizeStock = {};
  final Set<String> _selectedSizes = {};
  final Map<String, TextEditingController> _stockControllers = {};

  static const String BASE_URL = "https://api.damargtg.store/api";

  @override
  void initState() {
    super.initState();
    // Initialize size controllers
    for (var size in _availableSizes) {
      _sizeStock[size] = 0;
      _stockControllers[size] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaController.dispose();
    _warnaController.dispose();
    _deskripsiController.dispose();
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _pickImage() async {
    if (_pickedImageFiles.length >= _maxImages) {
      _showSnackBar(
        'Maksimal $_maxImages foto yang dapat dipilih',
        Colors.orange,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pilih Sumber Gambar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Hide camera option on web
                if (!kIsWeb)
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Kamera',
                    source: ImageSource.camera,
                  ),
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Galeri',
                  source: ImageSource.gallery,
                ),
                _buildImageSourceOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Multiple',
                  source: null,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    ImageSource? source,
  }) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);

        if (source == null) {
          // Handle multiple image selection
          final List<XFile> picked = await picker.pickMultiImage();
          if (picked.isNotEmpty) {
            for (var file in picked) {
              if (_pickedImageFiles.length < _maxImages) {
                if (kIsWeb) {
                  final bytes = await file.readAsBytes();
                  setState(() {
                    _pickedImageFiles.add(bytes);
                  });
                } else {
                  setState(() {
                    _pickedImageFiles.add(File(file.path));
                  });
                }
              }
            }
            if (picked.length > _maxImages - _pickedImageFiles.length) {
              _showSnackBar(
                'Beberapa foto tidak ditambahkan karena melebihi batas maksimal',
                Colors.orange,
              );
            }
          }
        } else {
          // Handle single image selection
          final picked = await picker.pickImage(source: source);
          if (picked != null) {
            if (kIsWeb) {
              final bytes = await picked.readAsBytes();
              setState(() {
                _pickedImageFiles.add(bytes);
              });
            } else {
              setState(() {
                _pickedImageFiles.add(File(picked.path));
              });
            }
          }
        }
      },
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 255, 227, 227),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCCCCCC)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: const Color(0xFF2B2B2B)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProduct() async {
    final nama = _namaController.text.trim();
    final harga = int.tryParse(_hargaController.text.trim());
    final kategori = _selectedCategory ?? '';
    final warna = _warnaController.text.trim();
    final deskripsi = _deskripsiController.text.trim();

    if (nama.isEmpty ||
        harga == null ||
        kategori.isEmpty ||
        warna.isEmpty ||
        deskripsi.isEmpty ||
        _pickedImageFiles.isEmpty ||
        _selectedSizes.isEmpty) {
      _showSnackBar('Harap lengkapi semua data', Colors.red);
      return;
    }

    final validSizeStock = <String, int>{};
    for (var size in _selectedSizes) {
      final stock = _sizeStock[size] ?? 0;
      if (stock > 0) validSizeStock[size] = stock;
    }

    if (validSizeStock.isEmpty) {
      _showSnackBar('Stok minimal satu ukuran harus > 0', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();

      debugPrint('➕ Adding product: $nama');

      // Create multipart request
      final uri = Uri.parse('$BASE_URL/api/admin/products');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['nama'] = nama;
      request.fields['harga'] = harga.toString();
      request.fields['kategori'] = kategori;
      request.fields['warna'] = warna;
      request.fields['deskripsi'] = deskripsi;
      request.fields['size_stock'] = jsonEncode(validSizeStock);

      // Add images
      for (int i = 0; i < _pickedImageFiles.length; i++) {
        if (kIsWeb) {
          // Web: Uint8List
          final bytes = _pickedImageFiles[i] as Uint8List;
          final multipartFile = http.MultipartFile.fromBytes(
            'files',
            bytes,
            filename: 'image_$i.jpg',
          );
          request.files.add(multipartFile);
        } else {
          // Mobile: File
          final file = _pickedImageFiles[i] as File;
          final multipartFile = await http.MultipartFile.fromPath(
            'files',
            file.path,
          );
          request.files.add(multipartFile);
        }
      }

      debugPrint('📤 Uploading ${request.files.length} images...');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📊 Add product response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Product added successfully');

        if (mounted) {
          _showSnackBar('Produk berhasil ditambahkan', Colors.green);
          Navigator.pop(context, true);
        }
      } else {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final message =
            body['error'] ?? body['message'] ?? 'Gagal menyimpan produk';

        debugPrint('❌ Add product failed: $message');

        if (mounted) {
          _showSnackBar(message.toString(), Colors.red);
        }
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      if (mounted) {
        _showSnackBar('Gagal menyimpan: $e', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedImageFiles.removeAt(index);
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF2B2B2B)),
        ),
        backgroundColor: color == Colors.red
            ? const Color(0xFFFFE3E3)
            : color == Colors.green
            ? const Color(0xFFE8F5E8)
            : const Color(0xFFFFF3CD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? type,
    int maxLines = 1,
    String? hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        style: const TextStyle(color: Color(0xFF2B2B2B)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF666666)),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF999999)),
          prefixIcon: Icon(icon, color: const Color(0xFF2B2B2B)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE00000), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSizeSelection() {
    if (_availableSizes.isEmpty) {
      return const Card(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Tidak ada ukuran tersedia',
            style: TextStyle(color: Color(0xFF2B2B2B)),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.straighten, color: Color(0xFF2B2B2B)),
                const SizedBox(width: 8),
                const Text(
                  'Pilih Ukuran dan Stok',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...(_availableSizes.map((size) {
              final isSelected = _selectedSizes.contains(size);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color.fromARGB(255, 255, 227, 227)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFE00000)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Theme(
                      data: Theme.of(context).copyWith(
                        checkboxTheme: CheckboxThemeData(
                          fillColor: WidgetStateProperty.resolveWith<Color>((
                            Set<WidgetState> states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return const Color(0xFFE00000);
                            }
                            return Colors.transparent;
                          }),
                          checkColor: WidgetStateProperty.all(Colors.white),
                          side: const BorderSide(color: Color(0xFFE00000)),
                        ),
                      ),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedSizes.add(size);
                            } else {
                              _selectedSizes.remove(size);
                              _sizeStock[size] = 0;
                              _stockControllers[size]?.text = '0';
                            }
                          });
                        },
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          size,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B2B2B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (isSelected)
                      Expanded(
                        child: TextField(
                          controller: _stockControllers[size],
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFF2B2B2B)),
                          decoration: InputDecoration(
                            labelText: 'Stok $size',
                            labelStyle: const TextStyle(
                              color: Color(0xFF666666),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE00000),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (val) {
                            _sizeStock[size] = int.tryParse(val) ?? 0;
                          },
                        ),
                      ),
                  ],
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_camera, color: Color(0xFF2B2B2B)),
                const SizedBox(width: 8),
                const Text(
                  'Foto Produk',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_pickedImageFiles.length}/$_maxImages',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Add Photo Button
            if (_pickedImageFiles.length < _maxImages)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo,
                        size: 40,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap untuk menambah foto',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Maksimal $_maxImages foto',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Display selected photos
            if (_pickedImageFiles.isNotEmpty) const SizedBox(height: 16),
            if (_pickedImageFiles.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _pickedImageFiles.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: index == 0
                                ? const Color(0xFFE00000)
                                : Colors.grey.shade300,
                            width: index == 0 ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _pickedImageFiles[index] is Uint8List
                              ? Image.memory(
                                  _pickedImageFiles[index],
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  _pickedImageFiles[index],
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      // Main photo indicator
                      if (index == 0)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE00000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Utama',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Remove button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFFE00000),
          secondary: const Color(0xFF2B2B2B),
          surface: Colors.white,
          background: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 0, 0, 0),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: const TextStyle(color: Color(0xFF2B2B2B)),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
            surfaceTintColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
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
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: !_isSizeLoaded
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE00000),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Memuat data ukuran...',
                      style: TextStyle(color: Color(0xFF2B2B2B)),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informasi Dasar Produk
                    Card(
                      elevation: 4,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Color(0xFF2B2B2B),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Informasi Produk',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF2B2B2B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _namaController,
                              label: 'Nama Produk',
                              icon: Icons.shopping_bag,
                              hint: 'contoh: Batik Tulis Parang',
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _hargaController,
                              label: 'Harga (Rp)',
                              icon: Icons.attach_money,
                              type: TextInputType.number,
                              hint: 'contoh: 150000',
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                style: const TextStyle(
                                  color: Color(0xFF2B2B2B),
                                ),
                                dropdownColor: Colors.white,
                                items: ['Pakaian', 'Bahan'].map((kategori) {
                                  return DropdownMenuItem(
                                    value: kategori,
                                    child: Text(
                                      kategori,
                                      style: const TextStyle(
                                        color: Color(0xFF2B2B2B),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategory = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  labelText: 'Kategori',
                                  labelStyle: const TextStyle(
                                    color: Color(0xFF666666),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.category,
                                    color: Color(0xFF2B2B2B),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE00000),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _warnaController,
                              label: 'Warna',
                              icon: Icons.palette,
                              hint: 'contoh: Biru Navy',
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _deskripsiController,
                              label: 'Deskripsi',
                              icon: Icons.description,
                              maxLines: 4,
                              hint: 'Deskripsi detail produk...',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPhotoSection(),
                    const SizedBox(height: 16),
                    _buildSizeSelection(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _addProduct,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE00000),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Menyimpan...'),
                                ],
                              )
                            : const Text('Tambah Produk'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
