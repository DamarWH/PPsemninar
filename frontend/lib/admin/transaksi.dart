import 'package:batiksekarniti/admin/transaksidetail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminTransactionPage extends StatefulWidget {
  const AdminTransactionPage({super.key});

  @override
  State<AdminTransactionPage> createState() => _AdminTransactionPageState();
}

class _AdminTransactionPageState extends State<AdminTransactionPage> {
  static const String baseUrl = 'https://damargtg.store/api';

  String _selectedFilter = 'all';
  bool _isLoading = true;
  String? _errorMessage;
  String? _token;
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];

  final Map<String, String> _statusFilters = {
    'all': 'Semua',
    'pending': 'Menunggu',
    'paid': 'Dibayar',
    'processing': 'Diproses',
    'shipping': 'Dikirim',
    'completed': 'Selesai',
    'cancelled': 'Dibatalkan',
  };

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token') ?? prefs.getString('auth_token');

    debugPrint('🔑 Token: ${_token?.substring(0, 20)}...');

    if (_token == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Token tidak ditemukan';
      });
      return;
    }

    await _loadAllTransactions();
  }

  Future<void> _loadAllTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('$baseUrl/admin/orders');
      debugPrint('📡 Calling: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('📡 Response Status: ${response.statusCode}');
      debugPrint('📡 Response Body: ${response.body}');

      if (response.statusCode == 401) {
        throw Exception('Unauthorized - Token tidak valid');
      }

      if (response.statusCode == 403) {
        throw Exception('Forbidden - Anda bukan admin');
      }

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final List<dynamic> ordersData = data['orders'] ?? [];

      debugPrint('✅ Loaded ${ordersData.length} orders from server');

      setState(() {
        _transactions = ordersData
            .map((order) => _mapOrderToTransaction(order))
            .toList();

        // Debug: Print semua transaksi
        debugPrint('📊 Total transactions: ${_transactions.length}');
        for (var t in _transactions) {
          debugPrint(
            '  - DB ID: ${t['id']}, Order ID: ${t['transactionId']}, Status: ${t['status']}',
          );
        }

        _filterTransactions();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading transactions: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data: ${e.toString()}';
      });
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
      'customerInfo': {
        'name': order['name'] ?? '',
        'phone': order['phone'] ?? '',
        'email': order['email'] ?? '',
        'address': order['address'] ?? '',
        'city': order['city'] ?? '',
        'postalCode': order['postal_code'] ?? '',
      },
      'notes': order['notes'] ?? '',
      'trackingNumber': order['tracking_number'],
      'userId': order['user_id'],
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
      debugPrint(
        '🔍 Filtered: ${_filteredTransactions.length} transactions (filter: $_selectedFilter)',
      );
    });
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.blue;
      case 'processing':
        return Colors.indigo;
      case 'shipping':
        return Colors.green;
      case 'completed':
        return Colors.teal;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'paid':
        return 'Dibayar';
      case 'processing':
        return 'Diproses';
      case 'shipping':
        return 'Dikirim';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  Future<void> _updateTransactionStatus(
    String orderId,
    String newStatus,
  ) async {
    try {
      debugPrint('🔄 Updating order DB ID: $orderId to status: $newStatus');

      final uri = Uri.parse('$baseUrl/admin/orders/$orderId/status');
      debugPrint('📡 PUT Request: $uri');

      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': newStatus}),
      );

      debugPrint('📡 Response Status: ${response.statusCode}');
      debugPrint('📡 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ Status updated successfully');
        await _loadAllTransactions();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Status transaksi berhasil diperbarui'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to update status: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showTrackingDialog(
    String orderId,
    String? currentTracking,
  ) async {
    final TextEditingController trackingController = TextEditingController();
    if (currentTracking != null) {
      trackingController.text = currentTracking;
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Input Resi Pengiriman',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: trackingController,
              decoration: InputDecoration(
                labelText: 'Nomor Resi',
                hintText: 'Masukkan nomor resi pengiriman',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                labelStyle: const TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (trackingController.text.trim().isNotEmpty) {
                try {
                  debugPrint('📦 Adding tracking to order DB ID: $orderId');
                  debugPrint(
                    '📦 Tracking number: ${trackingController.text.trim()}',
                  );

                  final uri = Uri.parse(
                    '$baseUrl/admin/orders/$orderId/tracking',
                  );
                  debugPrint('📡 PUT Request: $uri');

                  final response = await http.put(
                    uri,
                    headers: {
                      'Authorization': 'Bearer $_token',
                      'Content-Type': 'application/json',
                    },
                    body: json.encode({
                      'trackingNumber': trackingController.text.trim(),
                      'status': 'shipping',
                    }),
                  );

                  debugPrint('📡 Response Status: ${response.statusCode}');
                  debugPrint('📡 Response Body: ${response.body}');

                  if (response.statusCode == 200) {
                    debugPrint('✅ Tracking added successfully');
                    await _loadAllTransactions();

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Resi berhasil ditambahkan'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  } else {
                    throw Exception(
                      'Failed to update tracking: ${response.body}',
                    );
                  }
                } catch (e) {
                  debugPrint('❌ Error adding tracking: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.black,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Kelola Transaksi',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusFilters.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(entry.value, entry.key),
                );
              }).toList(),
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

  Widget _buildStatusChip(String status) {
    Color chipColor = _getStatusColor(status);
    String statusText = _getStatusDisplayText(status);

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Coba lagi dalam beberapa saat',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _loadAllTransactions();
            },
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
                ? 'Belum ada transaksi masuk'
                : 'Tidak ada transaksi dengan status ini',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        elevation: 2,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorState()
                : _filteredTransactions.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadAllTransactions,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredTransactions.length,
                      itemBuilder: (context, index) {
                        final transaction = _filteredTransactions[index];
                        return _buildTransactionCard(transaction);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final transactionId = transaction['transactionId']?.toString() ?? 'N/A';
    final status = transaction['status']?.toString() ?? 'pending';
    final totalAmount = transaction['totalAmount'] ?? 0;
    final totalItems = transaction['totalItems'] ?? 0;
    final createdAt = transaction['createdAt']?.toString() ?? '';
    final itemsList = transaction['items'];
    final List<Map<String, dynamic>> items = itemsList != null
        ? List<Map<String, dynamic>>.from(itemsList)
        : [];
    final customerInfo = transaction['customerInfo'] ?? {};
    final trackingNumber = transaction['trackingNumber']?.toString();
    final orderId = transaction['id']?.toString() ?? '';

    String dateStr = 'Tanggal tidak tersedia';
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        dateStr = DateFormat('dd MMM yyyy, HH:mm').format(date);
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                AdminTransactionDetailPage(transactionId: orderId),
          ),
        );
      },
      child: Container(
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            if (customerInfo.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          customerInfo['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          customerInfo['phone'] ?? '-',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${customerInfo['address'] ?? ''}, ${customerInfo['city'] ?? ''} ${customerInfo['postalCode'] ?? ''}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (items.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[300],
                    ),
                    child: items.first['foto']?.toString().isNotEmpty == true
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              items.first['foto'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                );
                              },
                            ),
                          )
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items.first['nama']?.toString() ??
                              items.first['name']?.toString() ??
                              'Produk',
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
                ],
              ),
              const SizedBox(height: 12),
            ],
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
            if (trackingNumber != null && trackingNumber.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resi: $trackingNumber',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (status == 'pending' || status == 'paid') ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        debugPrint('✅ Confirming order DB ID: $orderId');
                        _updateTransactionStatus(orderId, 'processing');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Konfirmasi'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        debugPrint('❌ Cancelling order DB ID: $orderId');
                        _updateTransactionStatus(orderId, 'cancelled');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Tolak'),
                    ),
                  ),
                ] else if (status == 'processing') ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        debugPrint(
                          '📦 Adding tracking to order DB ID: $orderId',
                        );
                        _showTrackingDialog(orderId, trackingNumber);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.local_shipping),
                      label: const Text('Input Resi'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
