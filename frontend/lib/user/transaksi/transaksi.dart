import 'package:batiksekarniti/user/transaksi/transaksidetail.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  static const String baseUrl = 'https://api.damargtg.store/api/api';

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  String _selectedFilter = 'all';
  bool _isLoading = true;
  bool _needsLogin = false;
  String? _errorMessage;
  String? _token;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    debugPrint('🔍 Loading user data...');
    final prefs = await SharedPreferences.getInstance();

    _token = prefs.getString('token') ?? prefs.getString('auth_token');
    _userId =
        prefs.getString('user_id') ??
        prefs.getString('userId') ??
        prefs.getString('user_email');

    debugPrint('🔑 Token: ${_token != null ? "Found" : "NULL"}');
    debugPrint('👤 User ID: $_userId');

    if (_token == null || _userId == null) {
      debugPrint('❌ Missing credentials');
      setState(() {
        _isLoading = false;
        _needsLogin = true;
      });
      return;
    }

    final isValid = await _validateToken();
    if (!isValid) {
      debugPrint('❌ Token invalid or expired');
      await _clearAuthData();
      setState(() {
        _isLoading = false;
        _needsLogin = true;
      });
      return;
    }

    debugPrint('✅ Token validated, loading transactions...');
    await _loadTransactions();
  }

  Future<bool> _validateToken() async {
    try {
      final uri = Uri.parse('$baseUrl/orders/$_userId');
      final response = await http
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('⚠️ Token validation error: $e');
      return true;
    }
  }

  Future<void> _clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('userId');
    } catch (e) {
      debugPrint('⚠️ Error clearing auth data: $e');
    }
  }

  Future<void> _loadTransactions() async {
    if (_token == null || _userId == null) {
      setState(() {
        _isLoading = false;
        _needsLogin = true;
      });
      return;
    }

    try {
      final uri = Uri.parse('$baseUrl/orders/$_userId');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 401) {
        await _clearAuthData();
        setState(() {
          _isLoading = false;
          _needsLogin = true;
          _errorMessage = 'Sesi Anda telah berakhir. Silakan login kembali.';
        });
        return;
      }

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<dynamic> ordersData = data['orders'] ?? [];

      if (mounted) {
        setState(() {
          _transactions = ordersData
              .map((order) => _mapOrderToTransaction(order))
              .toList();
          _filterTransactions();
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading transactions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data: ${e.toString()}';
        });
      }
    }
  }

  Map<String, dynamic> _mapOrderToTransaction(Map<String, dynamic> order) {
    List<dynamic> items = [];
    if (order['items'] != null) {
      if (order['items'] is String) {
        try {
          items = json.decode(order['items']);
        } catch (e) {
          debugPrint('⚠️ Error parsing items: $e');
        }
      } else if (order['items'] is List) {
        items = order['items'];
      }
    }

    return {
      'id': order['id']?.toString() ?? '',
      'transactionId': order['order_id'] ?? order['orderId'] ?? 'N/A',
      'createdAt':
          order['created_at'] ??
          order['date'] ??
          DateTime.now().toIso8601String(),
      'status': order['status'] ?? 'pending',
      'totalAmount': (order['total_price'] ?? 0).toDouble().toInt(),
      'totalItems': order['total_items'] ?? items.length,
      'items': items,
      'paymentMethod': order['payment_method'] ?? 'Belum dipilih',
      'shippingMethod': order['shipping_method'] ?? 'Belum dipilih',
      'name': order['name'] ?? '',
      'phone': order['phone'] ?? '',
      'email': order['email'] ?? '',
      'address': order['address'] ?? '',
      'city': order['city'] ?? '',
      'postalCode': order['postal_code'] ?? '',
      'notes': order['notes'] ?? '',
      'trackingNumber': order['tracking_number'],
    };
  }

  void _filterTransactions() {
    setState(() {
      if (_selectedFilter == 'all') {
        _filteredTransactions = List.from(_transactions);
      } else {
        _filteredTransactions = _transactions
            .where((t) => t['status'] == _selectedFilter)
            .toList();
      }
    });
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (e) {
      return 'Tanggal tidak tersedia';
    }
  }

  void _openTransactionDetail(Map<String, dynamic> transaction) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TransaksiDetailPage(transaction: transaction, token: _token ?? ''),
      ),
    );

    if (result == true) {
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _needsLogin ? _buildLoginPrompt() : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 100,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Image.asset('asset/icon/batiksekarniti.png', height: 60)],
      ),
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      foregroundColor: Colors.white,
      elevation: 2,
      centerTitle: true,
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? 'Silakan login terlebih dahulu',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        _buildFilterTabs(),
        Expanded(
          child: _filteredTransactions.isEmpty
              ? _buildEmptyState()
              : _buildTransactionList(),
        ),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: Colors.black,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'Filter Transaksi',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Menunggu', 'pending'),
                const SizedBox(width: 8),
                _buildFilterChip('Dibayar', 'paid'),
                const SizedBox(width: 8),
                _buildFilterChip('Diproses', 'processing'),
                const SizedBox(width: 8),
                _buildFilterChip('Dikirim', 'shipping'),
                const SizedBox(width: 8),
                _buildFilterChip('Selesai', 'completed'),
                const SizedBox(width: 8),
                _buildFilterChip('Gagal', 'failed'),
                const SizedBox(width: 8),
                _buildFilterChip('Dibatalkan', 'cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
          _filterTransactions();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Terjadi kesalahan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coba lagi dalam beberapa saat',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Tidak Ada Transaksi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? 'Mulai berbelanja dan buat transaksi pertama Anda'
                : 'Tidak ada transaksi dengan status ini',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredTransactions.length,
      itemBuilder: (context, index) {
        final transaction = _filteredTransactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final transactionId = transaction['transactionId']?.toString() ?? 'N/A';
    final status = transaction['status']?.toString() ?? 'pending';
    final totalAmount = (transaction['totalAmount'] ?? 0) is int
        ? transaction['totalAmount'] as int
        : (transaction['totalAmount'] as double).toInt();
    final totalItems = transaction['totalItems'] ?? 0;
    final createdAt = transaction['createdAt']?.toString() ?? '';
    final itemsList = transaction['items'];
    final List<Map<String, dynamic>> items = itemsList != null
        ? List<Map<String, dynamic>>.from(itemsList)
        : [];
    final trackingNumber = transaction['trackingNumber']?.toString();

    final dateStr = createdAt.isNotEmpty
        ? _formatDate(createdAt)
        : 'Tanggal tidak tersedia';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transactionId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isNotEmpty)
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[300],
                  ),
                  child: _buildProductImage(items.first),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getProductName(items.first),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalItems item${totalItems > 1 ? 's' : ''}' +
                            (items.length > 1
                                ? ' dan ${items.length - 1} lainnya'
                                : ''),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _openTransactionDetail(transaction),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Pembayaran',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                'Rp ${_formatPrice(totalAmount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          if (status == 'shipping' &&
              trackingNumber != null &&
              trackingNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.local_shipping,
                  color: Colors.purple,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resi: $trackingNumber',
                    style: const TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductImage(Map<String, dynamic> item) {
    final foto = item['foto']?.toString() ?? '';

    if (foto.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          foto,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.image, color: Colors.grey);
          },
        ),
      );
    }

    return const Icon(Icons.image, color: Colors.grey);
  }

  String _getProductName(Map<String, dynamic> item) {
    return item['nama']?.toString() ?? item['name']?.toString() ?? 'Produk';
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'pending':
        chipColor = Colors.orange;
        statusText = 'Menunggu';
        break;
      case 'paid':
        chipColor = Colors.blue;
        statusText = 'Dibayar';
        break;
      case 'completed':
        chipColor = Colors.green;
        statusText = 'Selesai';
        break;
      case 'cancelled':
        chipColor = Colors.red;
        statusText = 'Dibatalkan';
        break;
      case 'processing':
        chipColor = Colors.blue;
        statusText = 'Diproses';
        break;
      case 'shipping':
        chipColor = Colors.purple;
        statusText = 'Dikirim';
        break;
      case 'failed':
        chipColor = Colors.red;
        statusText = 'Gagal';
        break;
      default:
        chipColor = Colors.grey;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: chipColor,
        ),
      ),
    );
  }
}
