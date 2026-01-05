// lib/admin/home.dart - STYLE MATCHED TO FIREBASE VERSION
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Import pages - sesuaikan dengan struktur folder Anda
import 'package:batiksekarniti/admin/edit%20produk.dart';
import 'package:batiksekarniti/admin/tambahproduk.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  List<Map<String, dynamic>> products = [];
  bool loading = true;
  String searchQuery = '';
  String selectedCategory = 'Semua';
  final List<String> categories = ['Semua', 'Pakaian', 'Bahan'];

  static const String BASE_URL = "https://damargtg.store";

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _fetchProducts() async {
    setState(() => loading = true);
    try {
      final token = await _getToken();

      debugPrint('🔍 Fetching products...');

      final resp = await http.get(
        Uri.parse('$BASE_URL/api/admin/products'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('📊 Products response: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data is List)
            ? List<Map<String, dynamic>>.from(data)
            : <Map<String, dynamic>>[];

        debugPrint('✅ Loaded ${list.length} products');

        setState(() {
          products = list;
        });
      } else if (resp.statusCode == 401) {
        debugPrint('❌ Unauthorized');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        await prefs.remove('user_role');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesi berakhir, silakan login ulang'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        debugPrint('❌ Error: ${resp.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat produk (${resp.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => products = []);
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kesalahan jaringan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => products = []);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deleteProduct(String id, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Produk',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B2B2B),
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "$nama"?',
          style: const TextStyle(color: Color(0xFF2B2B2B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF666666)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE00000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final token = await _getToken();
    try {
      debugPrint('🗑️ Deleting product: $id');

      final resp = await http.delete(
        Uri.parse('$BASE_URL/api/admin/products/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 200 || resp.statusCode == 204) {
        debugPrint('✅ Product deleted');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Produk berhasil dihapus'),
              backgroundColor: const Color(0xFFE00000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _fetchProducts();
      } else {
        final body = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
        final msg = (body is Map && body['message'] != null)
            ? body['message']
            : 'Gagal menghapus produk';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth < 600) return 2;
    if (screenWidth < 900) return 3;
    return 4;
  }

  double _getChildAspectRatio(double screenWidth) {
    if (screenWidth < 600) return 0.75;
    if (screenWidth < 900) return 0.8;
    return 0.85;
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final numPrice = price is String ? int.tryParse(price) ?? 0 : price;
    return numPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final q = searchQuery.toLowerCase();
    return products.where((p) {
      final nama = (p['nama'] ?? '').toString().toLowerCase();
      final kategori = (p['kategori'] ?? '').toString().toLowerCase();
      final matchesCategory =
          selectedCategory.toLowerCase() == 'semua' ||
          kategori == selectedCategory.toLowerCase();
      final matchesSearch = q.isEmpty || nama.contains(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    final childAspectRatio = _getChildAspectRatio(screenWidth);

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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE00000),
        foregroundColor: Colors.white,
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddProductPage()),
          );
          if (res == true) _fetchProducts();
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Produk',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFFFFFFFF)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Cari produk...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Color(0xFF2B2B2B)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: Color(0xFFCCCCCC), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: Color(0xFFCCCCCC), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                    borderSide: BorderSide(color: Color(0xFFE00000), width: 2),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Stats and Categories
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Stats Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE00000),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.inventory,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Total: ${products.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Category buttons
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: categories.map((cat) {
                        final isSelected = selectedCategory == cat;
                        return GestureDetector(
                          onTap: () => setState(() => selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color.fromARGB(255, 0, 0, 0)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : const Color(0xFFCCCCCC),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF2B2B2B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Products Grid
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFE00000),
                      ),
                    ),
                  )
                : _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          searchQuery.isNotEmpty
                              ? 'Tidak ada produk yang cocok dengan pencarian "$searchQuery"'
                              : 'Tidak ada produk ditemukan',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF2B2B2B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _filteredProducts.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final p = _filteredProducts[index];
                      final stock = p['stok'] ?? 0;
                      final imageUrl = p['foto'] ?? '';
                      final productId =
                          (p['id']?.toString() ??
                          p['produk_id']?.toString() ??
                          '');

                      return Card(
                        elevation: 4,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image
                                Expanded(
                                  flex: 3,
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                Container(
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.image,
                                                    color: Color(0xFF2B2B2B),
                                                    size: 40,
                                                  ),
                                                ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(
                                              Icons.image,
                                              color: Color(0xFF2B2B2B),
                                              size: 40,
                                            ),
                                          ),
                                  ),
                                ),
                                // Info
                                Flexible(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p['nama'] ?? 'Tanpa Nama',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF2B2B2B),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rp ${_formatPrice(p['harga'] ?? 0)}',
                                          style: const TextStyle(
                                            color: Color.fromARGB(255, 0, 0, 0),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Flexible(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color.fromARGB(
                                                      255,
                                                      255,
                                                      227,
                                                      227,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    p['kategori'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Color(0xFF2B2B2B),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Stok: ${stock == 0 ? 'HABIS' : stock}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: stock == 0
                                                      ? Colors.grey
                                                      : const Color(0xFF666666),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Stock badge
                            if (stock == 0)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(20),
                                    ),
                                  ),
                                  child: const Text(
                                    'HABIS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),

                            // Admin menu
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: PopupMenuButton<String>(
                                  onSelected: (value) async {
                                    if (value == 'edit') {
                                      final res = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditProductPage(
                                            productId: productId,
                                            productData: p,
                                          ),
                                        ),
                                      );
                                      if (res == true) {
                                        _fetchProducts();
                                      }
                                    } else if (value == 'delete') {
                                      if (productId.isNotEmpty) {
                                        await _deleteProduct(
                                          productId,
                                          p['nama'] ?? 'Produk',
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: Color(0xFF2B2B2B),
                                          ),
                                          SizedBox(width: 8),
                                          Text('Edit Produk'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            size: 16,
                                            color: Color(0xFFE00000),
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Hapus Produk',
                                            style: TextStyle(
                                              color: Color(0xFFE00000),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
