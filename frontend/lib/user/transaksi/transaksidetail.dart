import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class TransaksiDetailPage extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final String token;

  const TransaksiDetailPage({
    super.key,
    required this.transaction,
    required this.token,
  });

  @override
  State<TransaksiDetailPage> createState() => _TransaksiDetailPageState();
}

class _TransaksiDetailPageState extends State<TransaksiDetailPage> {
  bool _isLoading = false;
  late Map<String, dynamic> _transaction;

  static const String baseUrl = 'http://localhost:3000/api';

  @override
  void initState() {
    super.initState();
    _transaction = Map.from(widget.transaction);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _confirmProductReceived() async {
    final dbId = _transaction['id'];

    if (dbId == null || dbId.toString().isEmpty) {
      _showSnackBar('ID transaksi tidak ditemukan', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Konfirmasi Penerimaan',
          style: TextStyle(
            color: Color(0xFF2B2B2B),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda sudah menerima produk ini dengan baik?',
              style: TextStyle(color: Color(0xFF2B2B2B), fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: const Text('Belum'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE00000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Ya, Sudah Diterima'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final uri = Uri.parse('$baseUrl/orders/$dbId');
        debugPrint('🔄 Updating order status: PUT $uri');

        final response = await http.put(
          uri,
          headers: {
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'status': 'completed'}),
        );

        debugPrint('📡 Response: ${response.statusCode}');

        if (response.statusCode == 200) {
          setState(() {
            _transaction['status'] = 'completed';
          });

          if (mounted) {
            _showSnackBar('Transaksi berhasil diselesaikan', isError: false);
            Navigator.of(context).pop(true);
          }
        } else {
          throw Exception('Server error: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('❌ Error: $e');
        if (mounted) {
          _showSnackBar('Gagal memperbarui status: $e', isError: true);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getStatusText(String status) {
    final statusMap = {
      'pending': 'Menunggu',
      'paid': 'Dibayar',
      'processing': 'Diproses',
      'shipping': 'Dikirim',
      'completed': 'Selesai',
      'failed': 'Gagal',
      'cancelled': 'Dibatalkan',
    };
    return statusMap[status] ?? status;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'paid':
        return Colors.blue;
      case 'processing':
        return Colors.orange;
      case 'shipping':
        return Colors.purple;
      case 'pending':
        return Colors.amber;
      case 'failed':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionId = _transaction['transactionId'] ?? 'N/A';
    final status = _transaction['status'] ?? 'pending';
    final createdAt =
        _transaction['createdAt'] ?? DateTime.now().toIso8601String();

    List<dynamic> itemsList = [];
    if (_transaction['items'] != null) {
      if (_transaction['items'] is String) {
        try {
          itemsList = json.decode(_transaction['items']);
        } catch (e) {
          debugPrint('Error parsing items: $e');
        }
      } else if (_transaction['items'] is List) {
        itemsList = _transaction['items'];
      }
    }

    final totalAmount = (_transaction['totalAmount'] ?? 0).toDouble();
    final totalItems = _transaction['totalItems'] ?? itemsList.length;
    final name = _transaction['name'] ?? '';
    final phone = _transaction['phone'] ?? '';
    final email = _transaction['email'] ?? '';
    final address = _transaction['address'] ?? '';
    final city = _transaction['city'] ?? '';
    final postalCode = _transaction['postalCode'] ?? '';
    final notes = _transaction['notes'] ?? '';
    final trackingNumber = _transaction['trackingNumber'] ?? '';
    final paymentMethod = _transaction['paymentMethod'] ?? 'Belum dipilih';
    final shippingMethod = _transaction['shippingMethod'] ?? 'Standar';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoSection('Informasi Pesanan', [
              _buildInfoRow('ID Pesanan', transactionId),
              _buildInfoRow('Tanggal', _formatDate(createdAt)),
              _buildInfoRow(
                'Status',
                _getStatusText(status),
                valueColor: _getStatusColor(status),
              ),
              _buildInfoRow('Total Item', '$totalItems item'),
            ]),
            const SizedBox(height: 20),
            _buildInfoSection('Informasi Pengiriman', [
              if (name.isNotEmpty) _buildInfoRow('Nama', name),
              if (email.isNotEmpty) _buildInfoRow('Email', email),
              if (phone.isNotEmpty) _buildInfoRow('Telepon', phone),
              if (address.isNotEmpty) _buildInfoRow('Alamat', address),
              if (city.isNotEmpty) _buildInfoRow('Kota', city),
              if (postalCode.isNotEmpty) _buildInfoRow('Kode Pos', postalCode),
            ]),
            const SizedBox(height: 20),
            _buildInfoSection('Metode', [
              _buildInfoRow('Pembayaran', paymentMethod),
              _buildInfoRow('Pengiriman', shippingMethod),
              if (trackingNumber.isNotEmpty)
                _buildInfoRow('No. Resi', trackingNumber),
            ]),
            const SizedBox(height: 20),
            if (status.toLowerCase() == 'shipping')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.local_shipping,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Pesanan Sedang Dikirim',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (trackingNumber.isNotEmpty)
                      Text(
                        'Nomor Resi: $trackingNumber',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'Silakan konfirmasi setelah menerima produk',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ),
            if (notes.isNotEmpty) ...[
              const Text(
                'Catatan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.2)),
                ),
                child: Text(
                  notes,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Produk Dipesan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 12),
            if (itemsList.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.2)),
                ),
                child: const Center(
                  child: Text(
                    'Tidak ada detail produk',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...itemsList.map((item) => _buildItemCard(item)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE00000).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Belanja',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  Text(
                    _formatCurrency(totalAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE00000),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (status.toLowerCase() == 'shipping')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE00000).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFE00000).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFFE00000),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Konfirmasi Penerimaan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE00000),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sudah menerima produk? Klik tombol di bawah untuk menyelesaikan transaksi.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _confirmProductReceived,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE00000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.check_circle, size: 18),
                        label: Text(
                          _isLoading ? 'Memproses...' : 'Produk Sudah Diterima',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (status.toLowerCase() == 'completed')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Transaksi Selesai',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Terima kasih telah berbelanja dengan kami!',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    final validChildren = children
        .where((w) => w is! SizedBox || (w as SizedBox).height != 0)
        .toList();
    if (validChildren.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withOpacity(0.2)),
          ),
          child: Column(children: validChildren),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    if (value.isEmpty || value == 'N/A' || value == '-')
      return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Container(
              padding: valueColor != null
                  ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
                  : null,
              decoration: valueColor != null
                  ? BoxDecoration(
                      color: valueColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: valueColor.withOpacity(0.3)),
                    )
                  : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? const Color(0xFF2B2B2B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final nama = item['nama'] ?? item['name'] ?? 'Produk';
    final quantity = item['quantity'] ?? item['jumlah'] ?? 1;
    final price = (item['harga'] ?? item['price'] ?? 0).toDouble();
    final size = item['size'] ?? '';
    String? imageUrl;
    if (item['foto'] != null && item['foto'].toString().isNotEmpty) {
      imageUrl = item['foto'];
    } else if (item['imageUrl'] != null &&
        item['imageUrl'].toString().isNotEmpty) {
      imageUrl = item['imageUrl'];
    } else if (item['gambar'] != null && item['gambar'].toString().isNotEmpty) {
      imageUrl = item['gambar'];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 24,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.shopping_bag,
                        color: Colors.grey,
                        size: 24,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nama,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2B2B2B),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (size.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Size: $size',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'x$quantity',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(price * quantity),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE00000),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
