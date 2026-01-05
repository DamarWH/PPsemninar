// user_homepage.dart
import 'dart:convert';
import 'package:batiksekarniti/user/detail.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  String selectedCategory = 'Semua';
  final List<String> categories = ['Semua', 'Pakaian', 'Bahan'];
  String searchQuery = '';
  String? recommendedSize;
  bool isLoading = false;

  // Controllers for size prediction
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController ageController = TextEditingController();

  // products from API
  Future<List<Map<String, dynamic>>>? productsFuture;

  @override
  void initState() {
    super.initState();
    productsFuture = fetchProducts();
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    try {
      // jika menggunakan token, ambil dari SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final uri = Uri.parse("https://damargtg.store:3000/api/products");
      final resp = await http.get(
        uri,
        headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode != 200) {
        throw Exception('Gagal mengambil produk: ${resp.statusCode}');
      }

      final List raw = jsonDecode(resp.body) as List;
      // Map produk server ke format yang kita pakai di UI
      final mapped = raw.map<Map<String, dynamic>>((item) {
        final m = Map<String, dynamic>.from(item as Map);
        // some servers return name/price; older code expects 'nama' & 'harga'
        if (!m.containsKey('nama') && m.containsKey('name')) {
          m['nama'] = m['name'];
        }
        if (!m.containsKey('harga') && m.containsKey('price')) {
          m['harga'] = m['price'];
        }
        // images: server returns images[] with image_url or product may have 'foto'
        if (!m.containsKey('foto')) {
          if (m.containsKey('images') && m['images'] is List) {
            final imgs = (m['images'] as List).cast();
            if (imgs.isNotEmpty) {
              // pilih primary jika ada
              final first = imgs.first;
              if (first is Map && first.containsKey('image_url')) {
                m['foto'] = first['image_url'];
              } else if (first is String) {
                m['foto'] = first;
              }
            }
          } else if (m.containsKey('image_url')) {
            m['foto'] = m['image_url'];
          } else if (m.containsKey('image') && m['image'] is String) {
            m['foto'] = m['image'];
          }
        }
        // size_stock: ensure map if present as json string
        if (m.containsKey('size_stock') && m['size_stock'] is String) {
          try {
            m['size_stock'] = jsonDecode(m['size_stock']);
          } catch (_) {}
        }
        return m;
      }).toList();

      return mapped;
    } catch (e) {
      // forward error to UI
      rethrow;
    }
  }

  // GET recommended size from ML service (adjust URL)
  Future<Map<String, dynamic>?> getRecommendedSize(
    int weight,
    int age,
    int height,
  ) async {
    try {
      final uri = Uri.parse(
        "https://knnpp-production.up.railway.app/predict",
      ); // ganti URL jika perlu
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'weight': weight, 'age': age, 'height': height}),
      );
      if (resp.statusCode == 200) {
        final Map<String, dynamic> j = jsonDecode(resp.body);
        return j;
      } else {
        return {'error': 'Predict failed: ${resp.statusCode}'};
      }
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Function to check if product is out of stock
  bool _isOutOfStock(Map<String, dynamic> data) {
    if (data.containsKey('size_stock') && data['size_stock'] is Map) {
      final sizeStockMap = Map<String, dynamic>.from(data['size_stock'] as Map);
      for (var stockValue in sizeStockMap.values) {
        int stock = 0;
        if (stockValue is num) {
          stock = stockValue.toInt();
        } else if (stockValue is String) {
          stock = int.tryParse(stockValue) ?? 0;
        }
        if (stock > 0) {
          return false;
        }
      }
      return true;
    }
    if (data.containsKey('stock')) {
      final stockValue = data['stock'];
      int stock = 0;
      if (stockValue is num) {
        stock = stockValue.toInt();
      } else if (stockValue is String) {
        stock = int.tryParse(stockValue) ?? 0;
      }
      return stock <= 0;
    }
    return false;
  }

  void _showSizePredictionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B2B2B),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sesuaikan\nUkuran Anda',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Height
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tinggi Badan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: heightController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Cm',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Weight
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Berat Badan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Kg',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Age
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Umur',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Th',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                heightController.clear();
                                weightController.clear();
                                ageController.clear();
                              },
                              child: const Text(
                                'Batal',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      if (heightController.text.isEmpty ||
                                          weightController.text.isEmpty ||
                                          ageController.text.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Mohon isi semua field',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }
                                      setDialogState(() {
                                        isLoading = true;
                                      });
                                      final height =
                                          int.tryParse(heightController.text) ??
                                          0;
                                      final weight =
                                          int.tryParse(weightController.text) ??
                                          0;
                                      final age =
                                          int.tryParse(ageController.text) ?? 0;

                                      // basic validation
                                      if (height < 100 ||
                                          height > 250 ||
                                          weight < 30 ||
                                          weight > 200 ||
                                          age < 10 ||
                                          age > 100) {
                                        setDialogState(() {
                                          isLoading = false;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Input diluar rentang wajar',
                                            ),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                        return;
                                      }

                                      try {
                                        final result = await getRecommendedSize(
                                          weight,
                                          age,
                                          height,
                                        );
                                        setDialogState(() {
                                          isLoading = false;
                                        });

                                        if (result == null) {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'API mengembalikan null',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        if (result.containsKey('error')) {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error: ${result['error']}',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        if (result.containsKey(
                                          'recommended_size',
                                        )) {
                                          final sizeRecommendation =
                                              result['recommended_size'];
                                          if (sizeRecommendation != null &&
                                              sizeRecommendation
                                                  .toString()
                                                  .isNotEmpty &&
                                              sizeRecommendation.toString() !=
                                                  'null') {
                                            setState(() {
                                              recommendedSize =
                                                  sizeRecommendation.toString();
                                            });
                                            Navigator.of(context).pop();
                                            heightController.clear();
                                            weightController.clear();
                                            ageController.clear();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Ukuran yang disarankan: $sizeRecommendation',
                                                ),
                                                backgroundColor: const Color(
                                                  0xFFE00000,
                                                ),
                                              ),
                                            );
                                          } else {
                                            Navigator.of(context).pop();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'API mengembalikan ukuran kosong atau tidak valid',
                                                ),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          }
                                        } else {
                                          Navigator.of(context).pop();
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Response tidak dikenali: ${result.keys.join(', ')}',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setDialogState(() {
                                          isLoading = false;
                                        });
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Terjadi kesalahan: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Color.fromARGB(255, 255, 0, 0),
                                            ),
                                      ),
                                    )
                                  : const Text(
                                      'Prediksi',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 0, 0, 0),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth < 600) return 2;
    if (screenWidth < 900) return 3;
    return 4;
  }

  double _getChildAspectRatio(double screenWidth) {
    if (screenWidth < 600) return 0.65;
    if (screenWidth < 900) return 0.68;
    return 0.72;
  }

  Future<void> _refresh() async {
    setState(() {
      productsFuture = fetchProducts();
    });
    await productsFuture;
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
          children: [Image.asset('asset/icon/batiksekarniti.png', height: 60)],
        ),
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
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
                    searchQuery = value.toLowerCase();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Temukan Batik Terbaik...',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showSizePredictionDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: recommendedSize != null
                          ? const Color.fromARGB(255, 255, 0, 0)
                          : const Color.fromARGB(255, 255, 255, 255),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: recommendedSize != null
                            ? const Color.fromARGB(255, 255, 255, 255)
                            : const Color.fromARGB(255, 255, 0, 0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: recommendedSize != null
                              ? const Color.fromARGB(255, 255, 255, 255)
                              : const Color.fromARGB(255, 255, 0, 0),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          recommendedSize != null
                              ? 'Ukuran: $recommendedSize'
                              : 'Rekomendasi Ukuran',
                          style: TextStyle(
                            color: recommendedSize != null
                                ? const Color.fromARGB(255, 0, 0, 0)
                                : const Color.fromARGB(255, 255, 0, 0),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (recommendedSize != null) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                recommendedSize = null;
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFE00000),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Terjadi kesalahan: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }
                  final allProducts = snapshot.data ?? [];

                  final filtered = allProducts.where((data) {
                    final nama = (data['nama'] ?? '').toString().toLowerCase();
                    final kategori = (data['kategori'] ?? '')
                        .toString()
                        .toLowerCase();
                    final matchesCategory =
                        selectedCategory.toLowerCase() == 'semua' ||
                        kategori == selectedCategory.toLowerCase();
                    final matchesSearch = nama.contains(searchQuery);
                    bool matchesSize = true;
                    if (recommendedSize != null &&
                        recommendedSize!.isNotEmpty) {
                      if (data.containsKey('size_stock') &&
                          data['size_stock'] is Map) {
                        final sizeStockMap = Map<String, dynamic>.from(
                          data['size_stock'] as Map,
                        );
                        final availableSizes = sizeStockMap.keys
                            .map((e) => e.toString().toLowerCase())
                            .toList();
                        matchesSize = availableSizes.contains(
                          recommendedSize!.toLowerCase(),
                        );
                        if (matchesSize) {
                          final stockValue =
                              sizeStockMap[recommendedSize] ??
                              sizeStockMap[recommendedSize!.toLowerCase()] ??
                              sizeStockMap[recommendedSize!.toUpperCase()];
                          if (stockValue != null) {
                            if (stockValue is num) {
                              matchesSize = stockValue > 0;
                            } else if (stockValue is String) {
                              final stockNum = int.tryParse(stockValue) ?? 0;
                              matchesSize = stockNum > 0;
                            }
                          }
                        }
                      } else {
                        matchesSize = false;
                      }
                    }
                    return matchesCategory && matchesSearch && matchesSize;
                  }).toList();

                  if (filtered.isEmpty) {
                    String emptyMessage = 'Tidak ada produk ditemukan';
                    if (recommendedSize != null) {
                      emptyMessage =
                          'Tidak ada produk dengan ukuran $recommendedSize yang tersedia';
                    }
                    if (searchQuery.isNotEmpty) {
                      emptyMessage =
                          'Tidak ada produk yang cocok dengan pencarian "$searchQuery"';
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            emptyMessage,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF2B2B2B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (recommendedSize != null) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  recommendedSize = null;
                                });
                              },
                              child: const Text(
                                'Hapus Filter Ukuran',
                                style: TextStyle(
                                  color: Color(0xFFE00000),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemBuilder: (context, index) {
                      final data = filtered[index];
                      final isOutOfStock = _isOutOfStock(data);
                      final imageUrl = (data['foto'] ?? '').toString();

                      return GestureDetector(
                        onTap: isOutOfStock
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailPage(
                                      product: {
                                        ...data,
                                        'docId': data['id'] ?? data['docId'],
                                      },
                                    ),
                                  ),
                                );
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Card(
                            elevation: isOutOfStock ? 1 : 4,
                            color: isOutOfStock
                                ? Colors.grey.shade200
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: isOutOfStock
                                  ? BorderSide(
                                      color: Colors.grey.shade400,
                                      width: 1,
                                    )
                                  : BorderSide.none,
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(16),
                                            ),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                color: isOutOfStock
                                                    ? Colors.grey
                                                    : null,
                                                colorBlendMode: isOutOfStock
                                                    ? BlendMode.saturation
                                                    : null,
                                                errorBuilder:
                                                    (context, error, st) {
                                                      return Container(
                                                        width: double.infinity,
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                        child: const Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          color: Colors.grey,
                                                          size: 40,
                                                        ),
                                                      );
                                                    },
                                              )
                                            : Container(
                                                width: double.infinity,
                                                color: Colors.grey.shade300,
                                                child: const Icon(
                                                  Icons.image,
                                                  color: Colors.grey,
                                                  size: 40,
                                                ),
                                              ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              height: 32,
                                              child: Text(
                                                data['nama'] ?? 'Nama Produk',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isOutOfStock
                                                      ? Colors.grey.shade600
                                                      : const Color(0xFF2B2B2B),
                                                  height: 1.2,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Rp ${_formatPrice(data['harga'] ?? 0)}',
                                              style: const TextStyle(
                                                color: Color.fromARGB(
                                                  255,
                                                  0,
                                                  0,
                                                  0,
                                                ),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Spacer(),
                                            if (data['kategori'] != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isOutOfStock
                                                      ? Colors.grey.shade400
                                                      : const Color(
                                                          0xFFE00000,
                                                        ).withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  data['kategori'],
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    color: isOutOfStock
                                                        ? Colors.grey.shade600
                                                        : const Color(
                                                            0xFFE00000,
                                                          ),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (isOutOfStock)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
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
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final numPrice = price is String
        ? int.tryParse(price) ?? 0
        : (price is num ? price.toInt() : 0);
    return numPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  @override
  void dispose() {
    heightController.dispose();
    weightController.dispose();
    ageController.dispose();
    super.dispose();
  }
}
