import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String? selectedSize;
  int quantity = 1;
  int currentImageIndex = 0;
  PageController pageController = PageController();

  // 🔥 GANTI dengan IP/URL backend Anda
  static const String BASE_URL = "https://damargtg.store";

  // Get list of image URLs from product data
  List<String> get imageUrls {
    // Cek apakah ada array images
    if (widget.product['images'] != null &&
        widget.product['images'] is List &&
        (widget.product['images'] as List).isNotEmpty) {
      final imgs = widget.product['images'] as List;
      return imgs.map<String>((img) {
        // Jika image berupa object dengan key image_url
        if (img is Map && img.containsKey('image_url')) {
          return img['image_url'].toString();
        }
        return img.toString();
      }).toList();
    }

    // Fallback ke single photo
    final foto = widget.product['foto'] ?? widget.product['image_url'];
    if (foto != null && foto.toString().isNotEmpty) {
      return [foto.toString()];
    }

    return [];
  }

  // Helper function to get available stock for selected size
  int get availableStock {
    if (selectedSize == null) return 0;
    final sizeStock = widget.product['size_stock'];

    if (sizeStock is Map && sizeStock.containsKey(selectedSize)) {
      final stockValue = sizeStock[selectedSize];
      if (stockValue is int) return stockValue;
      return int.tryParse(stockValue.toString()) ?? 0;
    }

    return 0;
  }

  // Helper function to get maximum stock
  int get maxStock {
    final sizeStock = widget.product['size_stock'];

    if (sizeStock is Map && sizeStock.isNotEmpty) {
      return availableStock;
    }

    // Fallback to total stock if no size variants
    final stockValue = widget.product['stock'] ?? widget.product['stok'] ?? 999;
    if (stockValue is int) return stockValue;
    return int.tryParse(stockValue.toString()) ?? 999;
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
      bottomNavigationBar: isDesktop ? null : _buildMobileBottomBar(),
    );
  }

  // Widget untuk bottom bar mobile
  Widget _buildMobileBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(child: _buildActionButtons(isDesktop: false)),
    );
  }

  // Layout untuk desktop/laptop
  Widget _buildDesktopLayout() {
    final sizes = widget.product['size_stock'] ?? {};

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        toolbarHeight: 100,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Image.asset('asset/icon/batiksekarniti.png', height: 60)],
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gambar produk - 50% lebar
              Expanded(
                flex: 5,
                child: Container(
                  height: MediaQuery.of(context).size.height - 100,
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _buildProductImageGallery(isDesktop: true),
                  ),
                ),
              ),

              // Detail produk - 50% lebar
              Expanded(
                flex: 5,
                child: Container(
                  height: MediaQuery.of(context).size.height - 100,
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductHeader(isDesktop: true),
                        const SizedBox(height: 24),
                        _buildPriceSection(isDesktop: true),
                        const SizedBox(height: 32),
                        if (sizes.isNotEmpty) ...[
                          _buildSizeSelection(isDesktop: true),
                          const SizedBox(height: 16),
                          _buildStockInfo(isDesktop: true),
                          const SizedBox(height: 32),
                        ],
                        _buildQuantitySelector(isDesktop: true),
                        const SizedBox(height: 32),
                        _buildDescription(isDesktop: true),
                        const SizedBox(height: 40),
                        _buildActionButtons(isDesktop: true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Layout untuk mobile/tablet
  Widget _buildMobileLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final sizes = widget.product['size_stock'] ?? {};

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: isTablet ? 450 : 350,
          floating: false,
          pinned: true,
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          foregroundColor: Colors.white,
          elevation: 2,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildProductImageGallery(isDesktop: false),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 32 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProductHeader(isDesktop: false),
                  const SizedBox(height: 24),
                  _buildPriceSection(isDesktop: false),
                  const SizedBox(height: 28),
                  if (sizes.isNotEmpty) ...[
                    _buildSizeSelection(isDesktop: false),
                    const SizedBox(height: 16),
                    _buildStockInfo(isDesktop: false),
                    const SizedBox(height: 28),
                  ],
                  _buildQuantitySelector(isDesktop: false),
                  const SizedBox(height: 28),
                  _buildDescription(isDesktop: false),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Widget info stok
  Widget _buildStockInfo({required bool isDesktop}) {
    final sizes = widget.product['size_stock'] ?? {};

    if (selectedSize == null) {
      return Container(
        padding: EdgeInsets.all(isDesktop ? 16 : 12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.blue.shade700,
              size: isDesktop ? 20 : 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pilih ukuran untuk melihat stok tersedia',
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final stock = availableStock;
    final isLowStock = stock > 0 && stock <= 5;
    final isOutOfStock = stock <= 0;

    Color backgroundColor;
    Color textColor;
    Color borderColor;
    IconData icon;
    String message;

    if (isOutOfStock) {
      backgroundColor = Colors.red.shade50;
      textColor = Colors.red.shade700;
      borderColor = Colors.red.shade200;
      icon = Icons.cancel_outlined;
      message = 'Stok ukuran $selectedSize habis';
    } else if (isLowStock) {
      backgroundColor = Colors.orange.shade50;
      textColor = Colors.orange.shade700;
      borderColor = Colors.orange.shade200;
      icon = Icons.warning_amber_outlined;
      message = 'Stok ukuran $selectedSize tersisa $stock pcs';
    } else {
      backgroundColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      borderColor = Colors.green.shade200;
      icon = Icons.check_circle_outline;
      message = 'Stok ukuran $selectedSize tersedia: $stock pcs';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(isDesktop ? 16 : 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: isDesktop ? 24 : 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: isDesktop ? 15 : 14,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget galeri gambar produk
  Widget _buildProductImageGallery({required bool isDesktop}) {
    final images = imageUrls;

    if (images.isEmpty) {
      return _buildNoImagePlaceholder();
    }

    if (images.length == 1) {
      return Stack(
        children: [
          Positioned.fill(child: _buildZoomableImage(images[0])),
          if (!isDesktop)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: pageController,
          onPageChanged: (index) => setState(() => currentImageIndex = index),
          itemCount: images.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) => _buildSwipeableImage(images[index]),
        ),
        if (images.length > 1)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentImageIndex + 1}/${images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (!isDesktop && images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: images.asMap().entries.map((entry) {
                bool isSelected = entry.key == currentImageIndex;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildSwipeableImage(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey.shade200,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                  : null,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE00000),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey.shade200,
          child: const Center(child: Icon(Icons.broken_image, size: 60)),
        );
      },
    );
  }

  Widget _buildZoomableImage(String imageUrl) {
    return InteractiveViewer(
      panEnabled: true,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.broken_image, size: 60)),
          );
        },
      ),
    );
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.image_rounded, size: 60, color: Colors.grey),
      ),
    );
  }

  Widget _buildProductHeader({required bool isDesktop}) {
    final fontSize = isDesktop
        ? 32.0
        : MediaQuery.of(context).size.width >= 600
        ? 28.0
        : 24.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.product['nama'] ?? widget.product['name'] ?? 'Nama Produk',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2B2B2B),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 227, 227),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.product['kategori'] ??
                widget.product['category'] ??
                'Kategori',
            style: TextStyle(
              color: const Color(0xFF2B2B2B),
              fontSize: isDesktop ? 14 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceSection({required bool isDesktop}) {
    final fontSize = isDesktop
        ? 32.0
        : MediaQuery.of(context).size.width >= 600
        ? 28.0
        : 24.0;
    final price = widget.product['harga'] ?? widget.product['price'] ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 0, 0, 0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Harga',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isDesktop ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Rp ${_formatPrice(price)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSelection({required bool isDesktop}) {
    final sizes = widget.product['size_stock'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pilih Ukuran',
          style: TextStyle(
            fontSize: isDesktop ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: sizes.entries.map<Widget>((entry) {
            final isSelected = selectedSize == entry.key;
            final stock = entry.value is int
                ? entry.value as int
                : int.tryParse(entry.value.toString()) ?? 0;
            final isAvailable = stock > 0;

            return GestureDetector(
              onTap: isAvailable
                  ? () {
                      setState(() {
                        selectedSize = entry.key;
                        quantity = 1;
                      });
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 16 : 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color.fromARGB(255, 0, 0, 0)
                      : isAvailable
                      ? Colors.white
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color.fromARGB(255, 0, 0, 0)
                        : isAvailable
                        ? const Color(0xFFCCCCCC)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isAvailable
                            ? const Color(0xFF2B2B2B)
                            : Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 18 : 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stok: $stock',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white70
                            : isAvailable
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                        fontSize: isDesktop ? 12 : 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector({required bool isDesktop}) {
    final currentMaxStock = maxStock;
    final canDecrease = quantity > 1;
    final canIncrease = quantity < currentMaxStock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Jumlah',
              style: TextStyle(
                fontSize: isDesktop ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2B2B2B),
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCCCCCC), width: 1.5),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: canDecrease
                        ? () => setState(() => quantity--)
                        : null,
                    icon: Icon(
                      Icons.remove,
                      color: canDecrease
                          ? const Color(0xFF2B2B2B)
                          : Colors.grey.shade400,
                      size: isDesktop ? 24 : 20,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 20 : 16,
                      vertical: 8,
                    ),
                    child: Text(
                      quantity.toString(),
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2B2B2B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: canIncrease
                        ? () => setState(() => quantity++)
                        : null,
                    icon: Icon(
                      Icons.add,
                      color: canIncrease
                          ? const Color(0xFF2B2B2B)
                          : Colors.grey.shade400,
                      size: isDesktop ? 24 : 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDescription({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deskripsi Produk',
          style: TextStyle(
            fontSize: isDesktop ? 20 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
          ),
          child: Text(
            widget.product['deskripsi'] ??
                widget.product['description'] ??
                'Tidak ada deskripsi tersedia.',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons({required bool isDesktop}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonHeight = isDesktop
        ? 56.0
        : screenWidth >= 600
        ? 52.0
        : 48.0;
    final fontSize = isDesktop
        ? 18.0
        : screenWidth >= 600
        ? 17.0
        : 16.0;

    return ElevatedButton(
      onPressed: () async {
        // Validasi ukuran
        final sizeStock = widget.product['size_stock'] ?? {};
        if (sizeStock.isNotEmpty && selectedSize == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silakan pilih ukuran terlebih dahulu'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Validasi stok
        final currentStock = sizeStock.isNotEmpty ? availableStock : maxStock;
        if (currentStock <= 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produk ini sedang habis'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Cek login
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token') ?? '';
        final userId =
            prefs.getString('user_id') ??
            prefs.getString('user_email') ??
            prefs.getString('user_display_name') ??
            '';

        if (token.isEmpty || userId.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silakan login terlebih dahulu'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Tambahkan ke cart
        final success = await _addToCart(token, userId);

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Produk berhasil ditambahkan ke keranjang'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // 🔥 TAMBAHKAN INI: Pop dengan signal refresh
          // Delay sedikit agar user sempat lihat snackbar
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            Navigator.pop(context, true); // true = signal untuk refresh cart
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal menambahkan ke keranjang'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE00000),
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: Size(double.infinity, buttonHeight),
      ),
      child: Text(
        'Tambah ke Keranjang',
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 🔥 METHOD UTAMA: Tambah ke keranjang via backend
  Future<bool> _addToCart(String token, String userId) async {
    try {
      final apiUrl = Uri.parse("$BASE_URL/api/cart");

      // Ambil product_id dengan prioritas field yang berbeda
      String productId = '';
      if (widget.product.containsKey('id') && widget.product['id'] != null) {
        productId = widget.product['id'].toString();
      } else if (widget.product.containsKey('product_id') &&
          widget.product['product_id'] != null) {
        productId = widget.product['product_id'].toString();
      }

      // Validasi product_id
      if (productId.isEmpty) {
        print('❌ product_id is missing from product data');
        print('❌ Available keys: ${widget.product.keys.toList()}');
        return false;
      }

      // Ambil harga dengan handling type conversion
      dynamic rawHarga =
          widget.product['harga'] ?? widget.product['price'] ?? 0;
      int hargaInt = 0;
      if (rawHarga is int) {
        hargaInt = rawHarga;
      } else if (rawHarga is double) {
        hargaInt = rawHarga.toInt();
      } else if (rawHarga is String) {
        hargaInt = int.tryParse(rawHarga) ?? 0;
      }

      // Persiapkan data sesuai struktur backend
      final body = {
        "user_id": userId,
        "product_id": productId,
        "nama": widget.product['nama'] ?? widget.product['name'] ?? '',
        "harga": hargaInt,
        "foto": imageUrls.isNotEmpty ? imageUrls.first : '',
        "size": selectedSize ?? '', // Backend expects string (bisa kosong)
        "quantity": quantity,
      };

      print('🔥 Sending to cart API: $apiUrl');
      print('🔥 Request body: ${jsonEncode(body)}');
      print(
        '🔥 Token: ${token.length > 20 ? "${token.substring(0, 20)}..." : token}',
      );

      final response = await http
          .post(
            apiUrl,
            headers: {
              "Content-Type": "application/json; charset=UTF-8",
              "Authorization": "Bearer $token",
              "Accept": "application/json",
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('❌ Request timeout after 15 seconds');
              throw Exception('Request timeout - Backend tidak merespons');
            },
          );

      print('🔥 Response status: ${response.statusCode}');
      print('🔥 Response headers: ${response.headers}');
      print('🔥 Response body: ${response.body}');

      // Success responses
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body);
          print('✅ Cart item added successfully!');
          print('✅ Response data: $responseData');
          return true;
        } catch (e) {
          print('⚠️ Response parsing warning: $e');
          // Jika response bukan JSON tapi status OK, tetap anggap berhasil
          return true;
        }
      }

      // Error responses with details
      if (response.statusCode == 400) {
        print('❌ Bad Request (400)');
        try {
          final errorData = jsonDecode(response.body);
          print('❌ Error from backend: ${errorData['error']}');

          // Show specific error to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorData['error'] ?? 'Data tidak valid'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        } catch (e) {
          print('❌ Error response: ${response.body}');
        }
        return false;
      }

      if (response.statusCode == 401) {
        print('❌ Unauthorized (401) - Token invalid atau expired');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sesi login Anda telah berakhir, silakan login kembali',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      if (response.statusCode == 500) {
        print('❌ Server Error (500)');
        print('❌ Backend response: ${response.body}');
        return false;
      }

      // Unexpected status code
      print('❌ Unexpected status code: ${response.statusCode}');
      print('❌ Response body: ${response.body}');
      return false;
    } on http.ClientException catch (e) {
      print('❌ Network/Client error: $e');
      print('❌ Pastikan:');
      print('   1. Backend berjalan di $BASE_URL');
      print('   2. Device/emulator bisa akses IP backend');
      print('   3. Tidak ada firewall yang memblokir');
      return false;
    } on FormatException catch (e) {
      print('❌ JSON Format error: $e');
      return false;
    } on Exception catch (e) {
      print('❌ General exception: $e');
      return false;
    } catch (e, stackTrace) {
      print('❌ Unexpected error in _addToCart: $e');
      print('❌ Stack trace:');
      print(stackTrace.toString().split('\n').take(5).join('\n'));
      return false;
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final numPrice = price is num ? price : int.tryParse(price.toString()) ?? 0;
    return numPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
