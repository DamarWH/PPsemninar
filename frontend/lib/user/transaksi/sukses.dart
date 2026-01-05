import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PaymentSuccessPage extends StatefulWidget {
  final String orderId;
  final String customerName;
  final int totalAmount;

  const PaymentSuccessPage({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.totalAmount,
  });

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  Map<String, dynamic>? transactionData;
  bool isLoading = true;
  String? _token;
  String? _userId;

  static const String baseUrl = 'https://damargtg.store:3000/api';

  @override
  void initState() {
    super.initState();

    // Setup animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _loadToken();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId =
        prefs.getString('user_id') ??
        prefs.getString('user_email') ??
        prefs.getString('userId');

    await _loadTransactionData();
  }

  Future<void> _loadTransactionData() async {
    if (_token == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      debugPrint('🔍 Loading transaction data for Order ID: ${widget.orderId}');

      // ⭐ Try to get order by order_id
      var uri = Uri.parse('$baseUrl/orders/by-order-id/${widget.orderId}');
      var response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📥 Order response: ${response.statusCode}');

      // If not found and orderId looks like database ID, try detail endpoint
      if (response.statusCode == 404 && int.tryParse(widget.orderId) != null) {
        debugPrint('🔄 Trying detail endpoint with database ID...');
        uri = Uri.parse('$baseUrl/orders/detail/${widget.orderId}');
        response = await http.get(
          uri,
          headers: {
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
        );
        debugPrint('📥 Detail response: ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final orderData = data['order'];

        debugPrint('✅ Order found');

        // Proses data items jika ada
        if (orderData['items'] != null) {
          List<dynamic> items;

          if (orderData['items'] is String) {
            try {
              items = jsonDecode(orderData['items']) as List<dynamic>;
            } catch (e) {
              debugPrint('⚠️ Error parsing items JSON: $e');
              items = [];
            }
          } else if (orderData['items'] is List) {
            items = orderData['items'] as List<dynamic>;
          } else {
            items = [];
          }

          debugPrint('📦 Items count: ${items.length}');

          // Enrich items dengan data produk
          final List<Map<String, dynamic>> enrichedItems = [];

          for (var item in items) {
            final enrichedItem = await _enrichItemData(item);
            enrichedItems.add(enrichedItem);
          }

          orderData['items'] = enrichedItems;
        }

        setState(() {
          transactionData = orderData;
          isLoading = false;
        });
      } else {
        debugPrint('⚠️ Order not found: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading transaction data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _enrichItemData(dynamic item) async {
    try {
      Map<String, dynamic> itemData = Map<String, dynamic>.from(item);

      // Cek berbagai kemungkinan field id produk
      String? productId =
          itemData['productId']?.toString() ??
          itemData['produkId']?.toString() ??
          itemData['id']?.toString() ??
          itemData['product_id']?.toString();

      if (productId != null && _token != null) {
        try {
          // Ambil data lengkap produk dari API
          final uri = Uri.parse('$baseUrl/products/$productId');
          final response = await http.get(
            uri,
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
          );

          if (response.statusCode == 200) {
            final productData = jsonDecode(response.body);

            // Merge data produk dengan data item
            itemData.addAll({
              'name':
                  productData['nama'] ??
                  productData['name'] ??
                  itemData['name'] ??
                  itemData['nama'] ??
                  'Produk',
              'price':
                  productData['harga'] ??
                  productData['price'] ??
                  itemData['price'] ??
                  itemData['harga'] ??
                  0,
              'imageUrl':
                  productData['foto'] ??
                  productData['gambar'] ??
                  productData['imageUrl'] ??
                  itemData['imageUrl'] ??
                  itemData['foto'],
            });
          }
        } catch (e) {
          debugPrint('⚠️ Error fetching product $productId: $e');
        }
      }

      // Pastikan quantity ada
      if (itemData['quantity'] == null && itemData['jumlah'] != null) {
        itemData['quantity'] = itemData['jumlah'];
      }

      // Pastikan price dalam format yang benar
      if (itemData['price'] is String) {
        itemData['price'] = int.tryParse(itemData['price'].toString()) ?? 0;
      }

      return itemData;
    } catch (e) {
      debugPrint('Error enriching item data: $e');
      return Map<String, dynamic>.from(item);
    }
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';

    try {
      DateTime date;
      if (dateTime is String) {
        date = DateTime.parse(dateTime);
      } else if (dateTime is DateTime) {
        date = dateTime;
      } else {
        return '-';
      }

      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('Error formatting date: $e');
      return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE00000)),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          // Success Icon with Animation
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(
                                  255,
                                  31,
                                  171,
                                  54,
                                ).withOpacity(0.1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color.fromARGB(
                                      255,
                                      31,
                                      171,
                                      54,
                                    ).withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                size: 80,
                                color: Color.fromARGB(255, 31, 171, 54),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Success Message
                          const Text(
                            'Pembayaran Berhasil!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B2B2B),
                            ),
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Terima kasih telah berbelanja dengan kami',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 40),

                          // Transaction Details Card
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: Colors.grey[100],
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Detail Transaksi',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2B2B2B),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _buildDetailRow(
                                    'Order ID',
                                    widget.orderId,
                                    isImportant: true,
                                  ),
                                  _buildDetailRow(
                                    'Nama Pemesan',
                                    widget.customerName,
                                  ),
                                  _buildDetailRow(
                                    'Total Pembayaran',
                                    'Rp ${_formatPrice(widget.totalAmount)}',
                                    isPrice: true,
                                  ),
                                  if (transactionData != null) ...[
                                    _buildDetailRow(
                                      'Status',
                                      _getStatusText(
                                        transactionData!['status'],
                                      ),
                                      statusColor: _getStatusColor(
                                        transactionData!['status'],
                                      ),
                                    ),
                                    if (transactionData!['payment_method'] !=
                                        null)
                                      _buildDetailRow(
                                        'Metode Pembayaran',
                                        transactionData!['payment_method'],
                                      ),
                                    if (transactionData!['shipping_method'] !=
                                        null)
                                      _buildDetailRow(
                                        'Metode Pengiriman',
                                        transactionData!['shipping_method'],
                                      ),
                                    _buildDetailRow(
                                      'Waktu Transaksi',
                                      _formatDateTime(
                                        transactionData!['created_at'] ??
                                            transactionData!['createdAt'],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Order Items
                          if (transactionData != null &&
                              transactionData!['items'] != null &&
                              (transactionData!['items'] as List).isNotEmpty)
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: Colors.grey[100],
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Item Pesanan',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2B2B2B),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ...List.generate(
                                      (transactionData!['items'] as List)
                                          .length,
                                      (index) {
                                        final item =
                                            transactionData!['items'][index];
                                        return _buildOrderItem(item);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 40),

                          // Action Buttons
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(
                                      context,
                                    ).pushNamedAndRemoveUntil(
                                      '/home',
                                      (route) => false,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE00000),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Kembali ke Beranda',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'paid':
        return 'Berhasil';
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'failed':
        return 'Gagal';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status ?? '-';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'paid':
        return const Color.fromARGB(255, 31, 171, 54);
      case 'pending':
        return Colors.orange;
      case 'failed':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isImportant = false,
    bool isPrice = false,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isImportant ? 16 : 14,
                fontWeight: isImportant || isPrice
                    ? FontWeight.bold
                    : FontWeight.w600,
                color:
                    statusColor ??
                    (isPrice
                        ? const Color(0xFFE00000)
                        : const Color(0xFF2B2B2B)),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final String itemName =
        item['name'] ?? item['nama'] ?? 'Produk Tidak Diketahui';
    final int itemPrice = _parsePrice(item['price'] ?? item['harga'] ?? 0);
    final int itemQuantity = item['quantity'] ?? item['jumlah'] ?? 1;
    final String? itemSize = item['size'] ?? item['ukuran'];
    final String? imageUrl = item['imageUrl'] ?? item['gambar'] ?? item['foto'];

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.image, color: Colors.grey[600]),
                    )
                  : Icon(Icons.shopping_bag, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF2B2B2B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (itemSize != null) ...[
                      Text(
                        'Size: $itemSize',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '${itemQuantity}x Rp ${_formatPrice(itemPrice)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            'Rp ${_formatPrice(itemQuantity * itemPrice)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFFE00000),
            ),
          ),
        ],
      ),
    );
  }

  int _parsePrice(dynamic price) {
    if (price == null) return 0;
    if (price is int) return price;
    if (price is double) return price.round();
    if (price is String) {
      String cleanPrice = price.replaceAll(RegExp(r'[^\d]'), '');
      return int.tryParse(cleanPrice) ?? 0;
    }
    return 0;
  }
}
