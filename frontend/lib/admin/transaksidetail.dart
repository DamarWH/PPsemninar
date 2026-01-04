// lib/admin/transaksi_detail.dart - FIXED VERSION
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminTransactionDetailPage extends StatefulWidget {
  final String transactionId;

  const AdminTransactionDetailPage({super.key, required this.transactionId});

  @override
  State<AdminTransactionDetailPage> createState() =>
      _AdminTransactionDetailPageState();
}

class _AdminTransactionDetailPageState
    extends State<AdminTransactionDetailPage> {
  Map<String, dynamic>? _transactionData;
  bool _isLoading = true;

  static const String BASE_URL = "http://localhost:3000";

  @override
  void initState() {
    super.initState();
    _fetchTransactionDetail();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _fetchTransactionDetail() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();

      // ⭐ FIXED: Gunakan endpoint yang benar
      final resp = await http.get(
        Uri.parse('$BASE_URL/api/admin/orders/${widget.transactionId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('🔍 Fetch detail - Status: ${resp.statusCode}');
      debugPrint('🔍 Response: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() {
          // ⭐ Response dari backend adalah {success: true, order: {...}}
          _transactionData = data['order'] ?? data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memuat detail (${resp.statusCode})')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetch detail: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
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
      case 'menunggu':
        return Colors.orange;
      case 'paid':
      case 'dibayar':
        return Colors.blue;
      case 'processing':
      case 'diproses':
        return Colors.blue;
      case 'shipping':
      case 'dikirim':
        return Colors.purple;
      case 'completed':
      case 'selesai':
        return Colors.green;
      case 'cancelled':
      case 'dibatalkan':
        return Colors.red;
      case 'failed':
      case 'gagal':
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
      case 'failed':
        return 'Gagal';
      default:
        return status;
    }
  }

  Future<void> _updateTransactionStatus(String newStatus) async {
    try {
      final token = await _getToken();

      // ⭐ FIXED: Gunakan endpoint yang benar
      final resp = await http.put(
        Uri.parse('$BASE_URL/api/admin/orders/${widget.transactionId}/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      debugPrint('🔄 Update status - Status: ${resp.statusCode}');
      debugPrint('🔄 Response: ${resp.body}');

      if (resp.statusCode == 200) {
        await _fetchTransactionDetail();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status berhasil diperbarui'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memperbarui status (${resp.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error update status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showTrackingDialog(String? currentTracking) async {
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
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (trackingController.text.trim().isNotEmpty) {
                try {
                  final token = await _getToken();

                  // ⭐ FIXED: Gunakan endpoint yang benar
                  final resp = await http.put(
                    Uri.parse(
                      '$BASE_URL/api/admin/orders/${widget.transactionId}/tracking',
                    ),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'trackingNumber': trackingController.text.trim(),
                      'status': 'shipping',
                    }),
                  );

                  debugPrint('📦 Add tracking - Status: ${resp.statusCode}');
                  debugPrint('📦 Response: ${resp.body}');

                  if (resp.statusCode == 200) {
                    await _fetchTransactionDetail();
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Resi berhasil ditambahkan'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Gagal menambahkan resi (${resp.statusCode})',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint('❌ Error add tracking: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, Widget content) {
    return Card(
      color: Colors.grey[50],
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

  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: 100,
            child: Text(
              "$label:",
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor = _getStatusColor(status);
    String statusText = _getStatusDisplayText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: chipColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Detail Transaksi'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.black),
        ),
      );
    }

    if (_transactionData == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Detail Transaksi'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Transaksi tidak ditemukan'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _transactionData!;
    final status = data['status'] ?? 'pending';

    // ⭐ Handle both snake_case and camelCase from backend
    final totalAmount =
        (data['total_price'] ??
        data['totalAmount'] ??
        data['total_amount'] ??
        0);
    final totalItems = data['total_items'] ?? data['totalItems'] ?? 0;
    final shippingMethod =
        data['shipping_method'] ?? data['shippingMethod'] ?? '-';
    final paymentMethod =
        data['payment_method'] ?? data['paymentMethod'] ?? '-';
    final trackingNumber = data['tracking_number'] ?? data['trackingNumber'];
    final paidAt = data['paid_at'] ?? data['paidAt'];
    final createdAt = data['created_at'] ?? data['createdAt'];
    final orderIdDisplay =
        data['order_id'] ?? data['orderId'] ?? widget.transactionId;

    // Parse items
    List<Map<String, dynamic>> items = [];
    if (data['items'] is String) {
      try {
        items = List<Map<String, dynamic>>.from(jsonDecode(data['items']));
      } catch (e) {
        debugPrint('⚠️ Error parsing items: $e');
        items = [];
      }
    } else if (data['items'] is List) {
      items = List<Map<String, dynamic>>.from(data['items']);
    }

    // Customer info from order table directly
    final customerName = data['name'] ?? '-';
    final customerEmail = data['email'] ?? '-';
    final customerPhone = data['phone'] ?? '-';
    final customerAddress = data['address'] ?? '-';
    final customerCity = data['city'] ?? '-';
    final customerPostalCode = data['postal_code'] ?? data['postalCode'] ?? '-';
    final customerNotes = data['notes'] ?? '';

    String dateStr = 'Tanggal tidak tersedia';
    try {
      if (createdAt != null) {
        final date = DateTime.parse(createdAt.toString());
        dateStr = DateFormat('dd MMMM yyyy, HH:mm').format(date);
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing date: $e');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID dan Status
            _buildSectionCard(
              'Informasi Transaksi',
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Order ID',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        orderIdDisplay,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tanggal',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(dateStr, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      _buildStatusChip(status),
                    ],
                  ),
                  if (paidAt != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dibayar Pada',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(DateTime.parse(paidAt.toString())),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Informasi Pelanggan
            _buildSectionCard(
              'Informasi Pelanggan',
              Column(
                children: [
                  _buildInfoRow('Nama', customerName, icon: Icons.person),
                  _buildInfoRow('Email', customerEmail, icon: Icons.email),
                  _buildInfoRow('Telepon', customerPhone, icon: Icons.phone),
                  _buildInfoRow(
                    'Alamat',
                    customerAddress,
                    icon: Icons.location_on,
                  ),
                  _buildInfoRow(
                    'Kota',
                    customerCity,
                    icon: Icons.location_city,
                  ),
                  _buildInfoRow(
                    'Kode Pos',
                    customerPostalCode,
                    icon: Icons.markunread_mailbox,
                  ),
                  if (customerNotes.isNotEmpty)
                    _buildInfoRow('Catatan', customerNotes, icon: Icons.note),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Informasi Pengiriman
            _buildSectionCard(
              'Informasi Pengiriman',
              Column(
                children: [
                  _buildInfoRow(
                    'Metode',
                    shippingMethod,
                    icon: Icons.local_shipping,
                  ),
                  _buildInfoRow(
                    'Pembayaran',
                    paymentMethod,
                    icon: Icons.payment,
                  ),
                  if (trackingNumber != null)
                    _buildInfoRow(
                      'Nomor Resi',
                      trackingNumber,
                      icon: Icons.qr_code,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Daftar Produk
            _buildSectionCard(
              'Daftar Produk ($totalItems item${totalItems > 1 ? 's' : ''})',
              Column(
                children: items.map((item) {
                  final itemName = item['nama'] ?? item['name'] ?? 'Produk';
                  final itemPrice = item['harga'] ?? item['price'] ?? 0;
                  final itemQty = item['quantity'] ?? item['jumlah'] ?? 1;
                  final itemSize = item['ukuran'] ?? item['size'] ?? '-';
                  final itemFoto = item['foto'] ?? item['image'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        // Product Image
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[300],
                          ),
                          child: itemFoto.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    itemFoto,
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

                        // Product Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ukuran: $itemSize',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Rp ${_formatPrice(itemPrice)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'x$itemQty',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // Ringkasan Pembayaran
            _buildSectionCard(
              'Ringkasan Pembayaran',
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Pembayaran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Rp ${_formatPrice(totalAmount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if (status == 'pending') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateTransactionStatus('processing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Konfirmasi Pesanan'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateTransactionStatus('cancelled'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Tolak Pesanan'),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'processing') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTrackingDialog(trackingNumber),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.local_shipping),
                  label: Text(
                    trackingNumber == null
                        ? 'Input Resi Pengiriman'
                        : 'Update Resi Pengiriman',
                  ),
                ),
              ),
            ] else if (status == 'shipping') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showTrackingDialog(trackingNumber),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.edit),
                  label: const Text('Update Resi Pengiriman'),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
