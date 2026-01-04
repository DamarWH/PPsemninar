// lib/admin/editproduk.dart - MYSQL BACKEND (FIREBASE STYLE)
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EditProductPage extends StatefulWidget {
  final String productId;
  final Map<String, dynamic> productData;

  const EditProductPage({
    super.key,
    required this.productId,
    required this.productData,
  });

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final picker = ImagePicker();
  final int _maxImages = 5;

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _colorController;
  String? _selectedCategory;

  List<dynamic> _pickedImageFiles = [];
  List<String> _currentImageUrls = [];
  List<String> _imagesToDelete = [];

  List<String> _availableSizes = [];
  final Map<String, int> _sizeStock = {};
  final Map<String, TextEditingController> _stockControllers = {};
  final Set<String> _selectedSizes = {};

  bool _isLoading = false;
  bool _isSizeLoaded = false;

  static const String BASE_URL = "http://localhost:3000";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.productData['nama'] ?? '',
    );
    _priceController = TextEditingController(
      text: widget.productData['harga']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.productData['deskripsi'] ?? '',
    );
    _colorController = TextEditingController(
      text: widget.productData['warna'] ?? '',
    );

    final kategori = widget.productData['kategori']?.toString().toLowerCase();
    if (kategori == 'pakaian') {
      _selectedCategory = 'Pakaian';
    } else if (kategori == 'bahan') {
      _selectedCategory = 'Bahan';
    } else {
      _selectedCategory = null;
    }

    _loadExistingPhotos();
    _loadSizes();
  }

  void _loadExistingPhotos() {
    final fotos = widget.productData['fotos'];
    if (fotos != null) {
      if (fotos is List) {
        _currentImageUrls = List<String>.from(fotos);
      } else if (fotos is String && fotos.isNotEmpty) {
        _currentImageUrls = [fotos];
      }
    } else {
      final foto = widget.productData['foto'];
      if (foto != null && foto.isNotEmpty) {
        _currentImageUrls = [foto];
      }
    }
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadSizes() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$BASE_URL/api/admin/settings/sizes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['available_sizes'] != null) {
          _availableSizes = List<String>.from(data['available_sizes']);
        } else {
          _availableSizes = ['S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
        }
      } else {
        _availableSizes = ['S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
      }
    } catch (e) {
      debugPrint('❌ Error fetching sizes: $e');
      _availableSizes = ['S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
    }

    final sizeData = widget.productData['size_stock'] ?? {};
    for (var size in _availableSizes) {
      int stok = 0;
      final rawValue = sizeData[size] ?? sizeData[size.toLowerCase()];

      if (rawValue != null) {
        if (rawValue is int) {
          stok = rawValue;
        } else if (rawValue is String) {
          stok = int.tryParse(rawValue) ?? 0;
        }
      }

      _stockControllers[size] = TextEditingController(text: stok.toString());
      if (stok > 0) _selectedSizes.add(size);
      _sizeStock[size] = stok;
    }

    setState(() {
      _isSizeLoaded = true;
    });
  }

  Future<void> _pickImage() async {
    if (_pickedImageFiles.length + _currentImageUrls.length >= _maxImages) {
      _showSnackBar('Maksimal $_maxImages foto', Colors.orange);
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
          final List<XFile> picked = await picker.pickMultiImage();
          if (picked.isNotEmpty) {
            for (var file in picked) {
              if (_pickedImageFiles.length + _currentImageUrls.length <
                  _maxImages) {
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
          }
        } else {
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

  void _removeNewImage(int index) {
    setState(() {
      _pickedImageFiles.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _imagesToDelete.add(_currentImageUrls[index]);
      _currentImageUrls.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final totalImages = _pickedImageFiles.length + _currentImageUrls.length;
    if (totalImages == 0) {
      _showSnackBar('Minimal 1 foto produk', Colors.orange);
      return;
    }

    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showSnackBar('Pilih kategori produk', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _getToken();
      final uri = Uri.parse('$BASE_URL/api/admin/products/${widget.productId}');
      final request = http.MultipartRequest('PUT', uri);

      request.headers['Authorization'] = 'Bearer $token';

      // Add text fields
      request.fields['nama'] = _nameController.text.trim();
      request.fields['harga'] = _priceController.text.trim();
      request.fields['kategori'] = _selectedCategory ?? '';
      request.fields['warna'] = _colorController.text.trim();
      request.fields['deskripsi'] = _descriptionController.text.trim();

      // Calculate and add size stock
      final validStock = <String, int>{};
      int totalStock = 0;
      for (var size in _selectedSizes) {
        final stok = int.tryParse(_stockControllers[size]?.text ?? '0') ?? 0;
        if (stok > 0) {
          validStock[size] = stok;
          totalStock += stok;
        }
      }
      request.fields['size_stock'] = jsonEncode(validStock);

      // Add existing images that weren't deleted
      request.fields['existing_images'] = jsonEncode(_currentImageUrls);

      // Add new images
      for (int i = 0; i < _pickedImageFiles.length; i++) {
        if (kIsWeb) {
          final bytes = _pickedImageFiles[i] as Uint8List;
          final multipartFile = http.MultipartFile.fromBytes(
            'files',
            bytes,
            filename: 'image_$i.jpg',
          );
          request.files.add(multipartFile);
        } else {
          final file = _pickedImageFiles[i] as File;
          final multipartFile = await http.MultipartFile.fromPath(
            'files',
            file.path,
          );
          request.files.add(multipartFile);
        }
      }

      debugPrint('📤 Updating product: ${_nameController.text}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📊 Update response: ${response.statusCode}');

      if (response.statusCode == 200) {
        debugPrint('✅ Product updated successfully');

        if (mounted) {
          _showSnackBar('✓ Produk berhasil diperbarui', Colors.green);
          Navigator.pop(context, true);
        }
      } else {
        final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
        final message =
            body['error'] ?? body['message'] ?? 'Gagal menyimpan perubahan';

        debugPrint('❌ Update failed: $message');

        if (mounted) {
          _showSnackBar(message.toString(), Colors.red);
        }
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      if (mounted) {
        _showSnackBar('Gagal menyimpan perubahan: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2B2B2B)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF666666), fontSize: 14),
          prefixIcon: icon != null
              ? Icon(icon, color: const Color(0xFF666666), size: 20)
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE00000), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        validator: (value) => value == null || value.isEmpty
            ? 'Field ini tidak boleh kosong'
            : null,
      ),
    );
  }

  Widget _buildSizeEditor() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE00000).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.straighten,
                    color: Color(0xFFE00000),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Ukuran & Stok',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._availableSizes.map((size) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedSizes.contains(size)
                      ? const Color(0xFFE00000).withOpacity(0.05)
                      : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedSizes.contains(size)
                        ? const Color(0xFFE00000).withOpacity(0.3)
                        : const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _selectedSizes.contains(size),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedSizes.add(size);
                          } else {
                            _selectedSizes.remove(size);
                            _stockControllers[size]?.text = '0';
                          }
                        });
                      },
                      activeColor: const Color(0xFFE00000),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedSizes.contains(size)
                            ? const Color(0xFFE00000)
                            : const Color(0xFF666666),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        size,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (_selectedSizes.contains(size))
                      Expanded(
                        child: TextFormField(
                          controller: _stockControllers[size],
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2B2B2B),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Jumlah Stok',
                            labelStyle: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFCCCCCC),
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFCCCCCC),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE00000),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        items: ['Pakaian', 'Bahan'].map((cat) {
          return DropdownMenuItem(
            value: cat,
            child: Text(
              cat,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2B2B2B)),
            ),
          );
        }).toList(),
        onChanged: (val) => setState(() => _selectedCategory = val),
        style: const TextStyle(fontSize: 14, color: Color(0xFF2B2B2B)),
        decoration: InputDecoration(
          labelText: 'Kategori Produk',
          labelStyle: const TextStyle(color: Color(0xFF666666), fontSize: 14),
          prefixIcon: const Icon(
            Icons.category,
            color: Color(0xFF666666),
            size: 20,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFCCCCCC), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE00000), width: 2),
          ),
        ),
        validator: (val) =>
            val == null || val.isEmpty ? 'Pilih kategori produk' : null,
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
                  '${_pickedImageFiles.length + _currentImageUrls.length}/$_maxImages',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Add Photo Button
            if (_pickedImageFiles.length + _currentImageUrls.length <
                _maxImages)
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

            // Display existing and new photos
            if (_currentImageUrls.isNotEmpty || _pickedImageFiles.isNotEmpty)
              const SizedBox(height: 16),
            if (_currentImageUrls.isNotEmpty || _pickedImageFiles.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _currentImageUrls.length + _pickedImageFiles.length,
                itemBuilder: (context, index) {
                  final isExisting = index < _currentImageUrls.length;
                  final isFirst = index == 0;

                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isFirst
                                ? const Color(0xFFE00000)
                                : Colors.grey.shade300,
                            width: isFirst ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: isExisting
                              ? Image.network(
                                  _currentImageUrls[index],
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return const Center(
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Color(0xFFE00000),
                                                ),
                                          ),
                                        );
                                      },
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                )
                              : (_pickedImageFiles[index -
                                            _currentImageUrls.length]
                                        is Uint8List
                                    ? Image.memory(
                                        _pickedImageFiles[index -
                                            _currentImageUrls.length],
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.file(
                                        _pickedImageFiles[index -
                                            _currentImageUrls.length],
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                      )),
                        ),
                      ),
                      // Main photo indicator
                      if (isFirst)
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
                          onTap: () {
                            if (isExisting) {
                              _removeExistingImage(index);
                            } else {
                              _removeNewImage(index - _currentImageUrls.length);
                            }
                          },
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('asset/icon/batiksekarniti.png', height: 40),
            const SizedBox(width: 10),
            const Text(
              'Edit Produk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE00000), Color(0xFFB71C1C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Edit Produk',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Perbarui informasi produk Anda',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form Fields
                  _buildTextField(
                    _nameController,
                    'Nama Produk',
                    icon: Icons.shopping_bag,
                  ),

                  _buildTextField(
                    _priceController,
                    'Harga (Rp)',
                    type: TextInputType.number,
                    icon: Icons.attach_money,
                  ),

                  _buildCategoryDropdown(),

                  _buildTextField(
                    _colorController,
                    'Warna',
                    icon: Icons.palette,
                  ),

                  _buildTextField(
                    _descriptionController,
                    'Deskripsi Produk',
                    maxLines: 4,
                    icon: Icons.description,
                  ),

                  _buildPhotoSection(),

                  _buildSizeEditor(),

                  // Save Button
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 24),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE00000),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        disabledBackgroundColor: const Color(0xFFCCCCCC),
                      ),
                      child: _isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Menyimpan...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Simpan Perubahan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _colorController.dispose();
    for (var controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
