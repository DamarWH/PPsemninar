// lib/admin/dashboard.dart - FIXED VERSION
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonthlyReportPage extends StatefulWidget {
  const MonthlyReportPage({super.key});

  @override
  State<MonthlyReportPage> createState() => _MonthlyReportPageState();
}

class _MonthlyReportPageState extends State<MonthlyReportPage> {
  DateTime _selectedMonth = DateTime.now();
  Map<String, dynamic>? _cachedReport;
  bool _isLoading = false;

  static const String BASE_URL = "http://172.20.10.3:3000";

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<Map<String, dynamic>> _generateMonthlyReport() async {
    if (!mounted) return {};

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _getToken();
      final startOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );
      final endOfMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      // Format tanggal untuk API
      final startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
      final endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);

      debugPrint('🔍 Fetching report: $startDate to $endDate');

      // ⭐ FIXED: Panggil endpoint admin/report
      final resp = await http.get(
        Uri.parse(
          '$BASE_URL/orders/admin/report?startDate=$startDate&endDate=$endDate', // ⭐ Tambah /orders
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      debugPrint('📊 Report response: ${resp.statusCode}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        debugPrint('📊 Transactions count: ${data['count']}');

        int totalTransactions = 0;
        int totalRevenue = 0;
        int completedTransactions = 0;
        int pendingTransactions = 0;
        int processingTransactions = 0;
        int shippingTransactions = 0;
        int cancelledTransactions = 0;
        Map<String, int> productSales = {};

        // Proses data transaksi
        final transactions = data['transactions'] ?? [];
        for (var trans in transactions) {
          totalTransactions++;
          final status = (trans['status'] ?? '').toString().toLowerCase();

          // ⭐ FIXED: Gunakan total_price dari backend (snake_case)
          final totalAmount =
              trans['total_price'] ??
              trans['totalAmount'] ??
              trans['total_amount'] ??
              0;

          switch (status) {
            case 'completed':
            case 'selesai':
              completedTransactions++;
              totalRevenue += totalAmount as int;
              break;
            case 'paid':
            case 'dibayar':
              completedTransactions++;
              totalRevenue += totalAmount as int;
              break;
            case 'pending':
            case 'menunggu':
              pendingTransactions++;
              break;
            case 'processing':
            case 'diproses':
              processingTransactions++;
              break;
            case 'shipping':
            case 'dikirim':
              shippingTransactions++;
              break;
            case 'cancelled':
            case 'dibatalkan':
              cancelledTransactions++;
              break;
          }

          // Hitung penjualan produk
          var items = trans['items'];

          // Parse items jika masih string
          if (items is String) {
            try {
              items = jsonDecode(items);
            } catch (e) {
              debugPrint('⚠️ Error parsing items: $e');
              items = [];
            }
          }

          // Process items
          if (items is List) {
            for (var item in items) {
              final productName = item['nama'] ?? item['name'] ?? 'Unknown';
              final quantity = item['quantity'] ?? item['jumlah'] ?? 1;
              productSales[productName] =
                  (productSales[productName] ?? 0) + (quantity as int);
            }
          }
        }

        // Sort produk berdasarkan penjualan
        final sortedProducts = productSales.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final report = {
          'totalTransactions': totalTransactions,
          'totalRevenue': totalRevenue,
          'completedTransactions': completedTransactions,
          'pendingTransactions': pendingTransactions,
          'processingTransactions': processingTransactions,
          'shippingTransactions': shippingTransactions,
          'cancelledTransactions': cancelledTransactions,
          'topProducts': sortedProducts.take(5).toList(),
        };

        debugPrint(
          '✅ Report generated: $totalTransactions transactions, Rp$totalRevenue revenue',
        );

        if (mounted) {
          setState(() {
            _cachedReport = report;
          });
        }

        return report;
      } else {
        debugPrint('❌ Report error: ${resp.statusCode} - ${resp.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal memuat laporan (${resp.statusCode})'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return {};
      }
    } catch (e) {
      debugPrint('❌ Exception loading report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kesalahan: $e'), backgroundColor: Colors.red),
        );
      }
      return {};
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedMonth) {
      setState(() {
        _selectedMonth = picked;
        _cachedReport = null; // Reset cache
      });
      _generateMonthlyReport();
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateMonthlyReport();
    });
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
        backgroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Periode Laporan',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMMM yyyy').format(_selectedMonth),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _selectMonth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Ubah'),
                ),
              ],
            ),
          ),

          // Report Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.black),
                        SizedBox(height: 16),
                        Text(
                          'Memuat laporan...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _cachedReport == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.assessment_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tidak Ada Data',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pilih bulan untuk melihat laporan',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _generateMonthlyReport,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Muat Laporan'),
                        ),
                      ],
                    ),
                  )
                : _buildReportContent(_cachedReport!),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent(Map<String, dynamic> report) {
    final totalTransactions = report['totalTransactions'] ?? 0;
    final totalRevenue = report['totalRevenue'] ?? 0;
    final completedTransactions = report['completedTransactions'] ?? 0;
    final pendingTransactions = report['pendingTransactions'] ?? 0;
    final processingTransactions = report['processingTransactions'] ?? 0;
    final shippingTransactions = report['shippingTransactions'] ?? 0;
    final cancelledTransactions = report['cancelledTransactions'] ?? 0;
    final topProducts =
        report['topProducts'] as List<MapEntry<String, int>>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenue Card
          _buildStatCard(
            'Total Pendapatan',
            'Rp ${_formatPrice(totalRevenue)}',
            Icons.attach_money,
            Colors.green,
          ),
          const SizedBox(height: 12),

          // Total Transactions
          _buildStatCard(
            'Total Transaksi',
            totalTransactions.toString(),
            Icons.receipt_long,
            Colors.blue,
          ),
          const SizedBox(height: 12),

          // Transaction Status Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Selesai',
                  completedTransactions.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Menunggu',
                  pendingTransactions.toString(),
                  Icons.pending,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Diproses',
                  processingTransactions.toString(),
                  Icons.hourglass_empty,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Dikirim',
                  shippingTransactions.toString(),
                  Icons.local_shipping,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildStatCard(
            'Dibatalkan',
            cancelledTransactions.toString(),
            Icons.cancel,
            Colors.red,
          ),

          const SizedBox(height: 24),

          // Top Products Section
          if (topProducts.isNotEmpty) ...[
            const Text(
              'Produk Terlaris',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Colors.amber
                            : index == 1
                            ? Colors.grey[400]
                            : index == 2
                            ? Colors.orange[300]
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        product.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${product.value} terjual',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada produk terjual',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
