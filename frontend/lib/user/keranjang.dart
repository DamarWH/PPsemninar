// lib/user/keranjang.dart
import 'dart:convert';
import 'package:batiksekarniti/user/transaksi/pengiriman.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with WidgetsBindingObserver {
  bool isLoading = true;
  String apiBase = "http://localhost:3000"; // 🔥 GANTI sesuai backend Anda
  String token = "";
  String userId = "";
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🔥 Register observer
    _initAndFetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🔥 Unregister observer
    super.dispose();
  }

  // 🔥 AUTO REFRESH: Dipanggil saat app kembali ke foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('🔥 App resumed, refreshing cart...');
      if (token.isNotEmpty && userId.isNotEmpty) {
        fetchCart();
      }
    }
  }

  Future<void> _initAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token') ?? '';
    userId = prefs.getString('user_id') ?? prefs.getString('user_email') ?? '';
    await fetchCart();
  }

  Future<void> fetchCart() async {
    setState(() => isLoading = true);
    try {
      if (token.isEmpty || userId.isEmpty) {
        items = [];
        setState(() => isLoading = false);
        return;
      }
      final uri = Uri.parse("$apiBase/api/cart?user_id=$userId");
      final resp = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        items = data
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();
        print('✅ Cart loaded: ${items.length} items');
      } else {
        print("❌ fetchCart failed: ${resp.statusCode} ${resp.body}");
        items = [];
      }
    } catch (e) {
      print("❌ fetchCart exception: $e");
      items = [];
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<bool> _updateQuantityApi(String cartId, int newQty) async {
    try {
      final uri = Uri.parse("$apiBase/api/cart/$cartId");
      final resp = await http.put(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"quantity": newQty}),
      );
      return resp.statusCode == 200;
    } catch (e) {
      print("❌ updateQuantity exception: $e");
      return false;
    }
  }

  Future<bool> _deleteCartApi(String cartId) async {
    try {
      final uri = Uri.parse("$apiBase/api/cart/$cartId");
      final resp = await http.delete(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      return resp.statusCode == 200;
    } catch (e) {
      print("❌ deleteCart exception: $e");
      return false;
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  int _parseToInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  Future<void> _updateQuantity(String cartId, int newQuantity) async {
    if (newQuantity < 1) return;
    final idx = items.indexWhere(
      (it) => it['id'].toString() == cartId.toString(),
    );
    if (idx == -1) return;
    final old = items[idx];
    final oldQty = _parseToInt(old['quantity']);

    // Optimistic update
    setState(() => items[idx]['quantity'] = newQuantity);

    final ok = await _updateQuantityApi(cartId, newQuantity);
    if (!ok) {
      // Rollback jika gagal
      setState(() => items[idx]['quantity'] = oldQty);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mengubah jumlah (cek stok)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCartItem(
    BuildContext context,
    String cartId,
    String itemName,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Hapus Item', style: TextStyle(color: Colors.white)),
        content: Text(
          'Apakah Anda yakin ingin menghapus "$itemName" dari keranjang?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text(
              'Hapus',
              style: TextStyle(color: Color(0xFFE00000)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await _deleteCartApi(cartId);
    if (ok) {
      items.removeWhere((it) => it['id'].toString() == cartId.toString());
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$itemName" berhasil dihapus dari keranjang'),
            backgroundColor: const Color(0xFFE00000),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menghapus item'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCartItem(Map<String, dynamic> data) {
    final nama = data['nama'] ?? '';
    final harga = _parseToInt(data['harga']);
    final imageUrl = data['foto'] ?? '';
    final quantity = _parseToInt(data['quantity']);
    final ukuran = (data['size'] ?? data['ukuran'] ?? '')?.toString() ?? '';
    final cartId = data['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[300],
            ),
            child: imageUrl.toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image, size: 30, color: Colors.grey),
                    ),
                  )
                : const Icon(Icons.image, size: 30, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (ukuran.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Ukuran: $ukuran',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rp ${_formatPrice(harga)}',
                      style: const TextStyle(
                        color: Color(0xFFE00000),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _updateQuantity(cartId, quantity - 1),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: quantity > 1
                                  ? const Color(0xFFE00000)
                                  : Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: quantity > 1 ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _updateQuantity(cartId, quantity + 1),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE00000),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: Color(0xFFE00000),
              size: 20,
            ),
            onPressed: () => _deleteCartItem(context, cartId, nama),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    if (items.isEmpty) return const SizedBox.shrink();
    int totalPrice = 0;
    int totalItems = 0;
    for (var it in items) {
      final harga = _parseToInt(it['harga']);
      final qty = _parseToInt(it['quantity']);
      totalPrice += harga * qty;
      totalItems += qty;
    }
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalItems item${totalItems > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp ${_formatPrice(totalPrice)}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () => _proceedToCheckout(items, totalPrice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE00000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Checkout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
  }

  void _proceedToCheckout(List<Map<String, dynamic>> docs, int totalPrice) {
    final List<Map<String, dynamic>> cartItems = [];
    final List<String> invalidItems = [];

    for (var data in docs) {
      final productId =
          data['product_id']?.toString() ?? data['produk_id']?.toString() ?? '';
      if (productId.isEmpty) {
        invalidItems.add(data['nama']?.toString() ?? 'Unknown Product');
        continue;
      }
      final nama = data['nama']?.toString() ?? 'Produk Tidak Dikenal';
      final harga = _parseToInt(data['harga']);
      final qty = _parseToInt(data['quantity']);
      final ukuran = data['size']?.toString() ?? '';
      if (ukuran.isEmpty) {
        invalidItems.add('$nama (ukuran tidak dipilih)');
        continue;
      }
      if (nama.isNotEmpty && harga > 0 && qty > 0) {
        cartItems.add({
          'id': data['id'],
          'produk_id': productId,
          'nama': nama,
          'harga': harga,
          'foto': data['foto']?.toString() ?? '',
          'jumlah': qty,
          'ukuran': ukuran,
          'kategori': data['kategori']?.toString() ?? '',
          'deskripsi': data['deskripsi']?.toString() ?? '',
          'user_id': data['user_id']?.toString() ?? userId,
          'waktu': data['created_at'] ?? DateTime.now().toIso8601String(),
          'subtotal': harga * qty,
        });
      } else {
        invalidItems.add('$nama (data tidak lengkap)');
      }
    }

    if (invalidItems.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Item Bermasalah Ditemukan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Item berikut tidak dapat diproses:'),
              const SizedBox(height: 8),
              ...invalidItems.map((i) => Text('• $i')),
              const SizedBox(height: 12),
              const Text(
                'Silakan hapus item bermasalah atau tambahkan ulang produk dengan data lengkap.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (cartItems.isEmpty) return;
    }

    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada item valid untuk diproses'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int validTotalItems = 0;
    int validTotalPrice = 0;
    for (var item in cartItems) {
      validTotalItems += item['jumlah'] as int;
      validTotalPrice += item['subtotal'] as int;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShippingPage(
          cartItems: cartItems,
          totalPrice: validTotalPrice,
          totalItems: validTotalItems,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE00000)),
            )
          : (token.isEmpty || userId.isEmpty)
          ? _buildLoginPrompt()
          : items.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.black,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Keranjang Anda',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: fetchCart,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _buildCartItem(items[i]),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomSection(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 100,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Image.asset('asset/icon/batiksekarniti.png', height: 60)],
      ),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
    );
  }

  Widget _buildEmptyCart() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Keranjang Anda Kosong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Mulai berbelanja dan tambahkan produk ke keranjang',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Silakan login terlebih dahulu',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
