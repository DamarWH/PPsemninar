// lib/admin/transaksi_detail.dart - FIXED PRINT FEATURE
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  static const String BASE_URL = "https://damargtg.store";

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

  // 🖨️ PRINT SHIPPING LABEL - FIXED VERSION
  Future<void> _printShippingLabel() async {
    debugPrint('🖨️ Print button clicked');

    if (_transactionData == null) {
      debugPrint('❌ Transaction data is null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data transaksi tidak tersedia'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      debugPrint('📄 Starting PDF generation...');

      final data = _transactionData!;
      final orderIdDisplay =
          data['order_id'] ?? data['orderId'] ?? widget.transactionId;
      final customerName = data['name'] ?? '-';
      final customerPhone = data['phone'] ?? '-';
      final customerAddress = data['address'] ?? '-';
      final customerCity = data['city'] ?? '-';
      final customerPostalCode =
          data['postal_code'] ?? data['postalCode'] ?? '-';
      final trackingNumber =
          data['tracking_number'] ?? data['trackingNumber'] ?? '-';
      final shippingMethod =
          data['shipping_method'] ?? data['shippingMethod'] ?? '-';

      debugPrint('📦 Order ID: $orderIdDisplay');
      debugPrint('👤 Customer: $customerName');

      // Parse items
      List<Map<String, dynamic>> items = [];
      if (data['items'] is String) {
        try {
          items = List<Map<String, dynamic>>.from(jsonDecode(data['items']));
        } catch (e) {
          debugPrint('⚠️ Error parsing items from string: $e');
          items = [];
        }
      } else if (data['items'] is List) {
        items = List<Map<String, dynamic>>.from(data['items']);
      }

      debugPrint('📦 Total items: ${items.length}');

      final pdf = pw.Document();

      // Load logo
      debugPrint('🖼️ Loading logo...');
      pw.ImageProvider? logoImage;
      try {
        final logoData = await rootBundle.load(
          'frontend/asset/icon/batiksekarniti.png',
        );
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
        debugPrint('✅ Logo loaded successfully');
      } catch (e) {
        debugPrint('⚠️ Logo load failed: $e');
        // Continue without logo
      }

      debugPrint('📝 Building PDF page...');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.black,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          // Logo (optional)
                          if (logoImage != null) ...[
                            pw.Container(
                              width: 48,
                              height: 48,
                              decoration: pw.BoxDecoration(
                                borderRadius: pw.BorderRadius.circular(6),
                              ),
                              child: pw.Image(
                                logoImage,
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                            pw.SizedBox(width: 12),
                          ],
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'LABEL PENGIRIMAN',
                                style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 22,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Batik Sekarniti',
                                style: const pw.TextStyle(
                                  color: PdfColors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Order ID',
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                            ),
                          ),
                          pw.Text(
                            orderIdDisplay,
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Informasi Pengiriman
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'INFORMASI PENGIRIMAN',
                            style: pw.TextStyle(
                              fontSize: 16,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            shippingMethod,
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.Divider(thickness: 1),
                      pw.SizedBox(height: 10),

                      // Nomor Resi
                      if (trackingNumber != '-') ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey200,
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'NOMOR RESI',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.grey700,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                trackingNumber,
                                style: pw.TextStyle(
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 20),
                      ],

                      // Info Penerima
                      pw.Text(
                        'PENERIMA',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        customerName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        customerPhone,
                        style: const pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 12),

                      pw.Text(
                        'ALAMAT TUJUAN',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        customerAddress,
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '$customerCity, $customerPostalCode',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 30),

                // Daftar Produk
                pw.Text(
                  'DAFTAR PRODUK',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              'Nama Produk',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              'Ukuran',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            flex: 1,
                            child: pw.Text(
                              'Qty',
                              style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      pw.Divider(),
                      ...items.map((item) {
                        final itemName =
                            item['nama'] ?? item['name'] ?? 'Produk';
                        final itemQty = item['quantity'] ?? item['jumlah'] ?? 1;
                        final itemSize = item['ukuran'] ?? item['size'] ?? '-';

                        return pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Row(
                            children: [
                              pw.Expanded(
                                flex: 3,
                                child: pw.Text(
                                  itemName,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  itemSize,
                                  style: const pw.TextStyle(fontSize: 10),
                                ),
                              ),
                              pw.Expanded(
                                flex: 1,
                                child: pw.Text(
                                  'x$itemQty',
                                  style: const pw.TextStyle(fontSize: 10),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),

                pw.Spacer(),

                // Footer
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'CATATAN PENTING',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '• Harap periksa kesesuaian alamat dan nomor telepon penerima',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        '• Pastikan paket dikemas dengan baik dan aman',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        '• Simpan bukti pengiriman untuk keperluan tracking',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      debugPrint('✅ PDF page built successfully');
      debugPrint('🖨️ Opening print dialog...');

      // Print atau share PDF
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          debugPrint('📄 Generating PDF for format: ${format.toString()}');
          return pdf.save();
        },
      );

      debugPrint('✅ Print dialog opened successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error during print: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
        actions: [
          // 🖨️ PRINT BUTTON
          if (status == 'shipping' || status == 'processing')
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () {
                debugPrint('🖨️ Print icon pressed');
                _printShippingLabel();
              },
              tooltip: 'Cetak Label Pengiriman',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _printShippingLabel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                  ),
                ],
              ),
            ] else if (status == 'shipping') ...[
              Row(
                children: [
                  Expanded(
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
                      label: const Text('Update Resi'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _printShippingLabel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
