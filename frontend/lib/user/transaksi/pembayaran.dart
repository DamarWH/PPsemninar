import 'dart:convert';
import 'package:batiksekarniti/user/transaksi/sukses.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class PembayaranPage extends StatefulWidget {
  final double totalHarga;
  final List<Map<String, dynamic>> cartItems;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String postalCode;
  final String notes;

  const PembayaranPage({
    super.key,
    required this.totalHarga,
    required this.cartItems,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.postalCode,
    this.notes = '',
  });

  @override
  State<PembayaranPage> createState() => _PembayaranPageState();
}

class _PembayaranPageState extends State<PembayaranPage> {
  WebViewController? _controller;
  bool isLoading = true;
  String? errorMessage;
  String? transactionToken;
  bool _isProcessingPayment = false;
  String? _token;
  String? _userId;
  String? _orderId;
  String? _orderDbId;
  bool _orderCreated = false;
  bool _paymentWindowOpened = false;

  static const String baseUrl = 'https://api.damargtg.store/api/api';
  static const String midtransUrl =
      'https://midtrans-backend-production-62fb.up.railway.app';

  @override
  void initState() {
    super.initState();
    debugPrint(
      '🚀 ========== PAYMENT PAGE INIT (${kIsWeb ? "WEB" : "MOBILE"}) ==========',
    );
    _initializeWebView();
    _loadUserData();
  }

  void _initializeWebView() {
    if (kIsWeb) {
      debugPrint('⚠️ Running on WEB - will use browser redirect + polling');
      return;
    }

    debugPrint('🔧 Initializing WebView for mobile...');

    late final PlatformWebViewControllerCreationParams params;

    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('📊 WebView loading: $progress%');
          },
          onPageStarted: (String url) {
            debugPrint('🔥 ========== PAGE STARTED ==========');
            debugPrint('🔗 URL: $url');
            setState(() => isLoading = true);
            _checkPaymentStatus(url);
          },
          onPageFinished: (String url) {
            debugPrint('✅ ========== PAGE FINISHED ==========');
            debugPrint('🔗 URL: $url');
            setState(() => isLoading = false);
            _checkPaymentStatus(url);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ WEB ERROR: ${error.description}');
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🧭 NAVIGATION: ${request.url}');
            _checkPaymentStatus(request.url);
            return NavigationDecision.navigate;
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
    debugPrint('✅ WebView initialized');
  }

  Future<void> _loadUserData() async {
    try {
      debugPrint('📦 Loading user data...');

      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token') ?? prefs.getString('auth_token');
      _userId =
          prefs.getString('user_id') ??
          prefs.getString('userId') ??
          prefs.getString('user_email');

      debugPrint(
        '🔑 Token: ${_token != null ? "${_token!.substring(0, 20)}..." : "NULL"}',
      );
      debugPrint('👤 User ID: $_userId');

      if (_token == null || _userId == null) {
        throw Exception(
          'Token atau User ID tidak ditemukan. Silakan login kembali.',
        );
      }

      await _startPaymentProcess();
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal memuat data user: $e';
      });
    }
  }

  Future<void> _startPaymentProcess() async {
    try {
      debugPrint('💳 Starting payment process...');

      if (_orderCreated && transactionToken != null) {
        debugPrint('⚠️ Payment already in progress');
        return;
      }

      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Step 1: Create order
      if (!_orderCreated) {
        await _createOrderInDatabase();
      }

      // Step 2: Create Midtrans transaction
      await _createMidtransTransaction();
    } catch (e) {
      debugPrint('❌ Payment process error: $e');
      setState(() {
        isLoading = false;
        errorMessage = _formatError(e.toString());
      });
    }
  }

  String _formatError(String error) {
    if (error.contains('SocketException')) {
      return 'Tidak ada koneksi internet';
    } else if (error.contains('TimeoutException')) {
      return 'Koneksi timeout';
    }
    return error.length > 150 ? error.substring(0, 150) + "..." : error;
  }

  Future<void> _createOrderInDatabase() async {
    try {
      debugPrint('📝 Creating order in database...');

      final uri = Uri.parse('$baseUrl/orders');

      // Siapkan items untuk disimpan di database
      final itemsForDb = widget.cartItems.map((item) {
        return {
          'productId':
              item['produkId'] ??
              item['produk_id'] ??
              item['product_id'] ??
              item['id'],
          'name': item['nama'] ?? item['name'] ?? 'Unknown',
          'size': item['size'] ?? item['ukuran'] ?? '',
          'quantity': item['quantity'] ?? item['jumlah'] ?? 1,
          'price': item['harga'] ?? item['price'] ?? 0,
        };
      }).toList();

      debugPrint('📦 Items to save: ${jsonEncode(itemsForDb)}');

      final requestBody = {
        'user_id': _userId,
        'name': widget.name,
        'email': widget.email.isEmpty ? 'customer@example.com' : widget.email,
        'phone': widget.phone,
        'address': widget.address,
        'city': widget.city,
        'postal_code': widget.postalCode,
        'notes': widget.notes,
        'total_items': widget.cartItems.length,
        'total_price': widget.totalHarga.toInt(),
        'status': 'pending',
        'items': itemsForDb,
      };

      debugPrint('📤 Request body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('📥 Order response: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _orderId = data['order_id'] ?? data['orderId'];
        _orderDbId = data['dbId']?.toString() ?? data['id']?.toString();
        _orderCreated = true;

        debugPrint('✅ Order created: $_orderId (DB ID: $_orderDbId)');
      } else {
        throw Exception(
          'Gagal membuat order (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating order: $e');
      rethrow;
    }
  }

  Future<void> _createMidtransTransaction() async {
    if (_orderId == null) throw Exception('Order ID tidak tersedia');

    try {
      debugPrint('💰 Creating Midtrans transaction...');

      final url = Uri.parse('$midtransUrl/create-transaction');

      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "order_id": _orderId,
              "gross_amount": widget.totalHarga.toInt(),
              "customer": {
                "name": widget.name,
                "email": widget.email.isEmpty
                    ? "customer@example.com"
                    : widget.email,
                "phone": widget.phone.isEmpty ? "081234567890" : widget.phone,
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 Midtrans response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final paymentUrl = data['redirect_url'];
        transactionToken = data['token'];

        debugPrint('✅ Transaction created!');
        debugPrint('🔗 Payment URL: $paymentUrl');

        if (kIsWeb) {
          // WEB: Open in new tab + start polling
          _openPaymentInBrowser(paymentUrl);
          // ⭐ Delay polling 5 detik untuk kasih waktu user bayar
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _startPollingPaymentStatus();
          });
        } else if (_controller != null && mounted) {
          // MOBILE: Load in WebView
          await _controller!.loadRequest(Uri.parse(paymentUrl));
          setState(() => isLoading = true);
        }
      } else {
        throw Exception("Gagal membuat transaksi: ${response.body}");
      }
    } catch (e) {
      debugPrint('❌ Error creating Midtrans: $e');
      rethrow;
    }
  }

  // WEB: Open payment in browser
  void _openPaymentInBrowser(String paymentUrl) async {
    debugPrint('🌐 Opening payment URL in browser...');
    debugPrint('🌐 URL: $paymentUrl');

    setState(() {
      isLoading = false;
      _paymentWindowOpened = true;
    });

    final uri = Uri.parse(paymentUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      debugPrint('✅ Payment URL opened in external browser');
    } else {
      debugPrint('❌ Cannot launch URL');
      setState(() {
        errorMessage = "Tidak dapat membuka halaman pembayaran";
      });
    }
  }

  // WEB: Poll payment status every 5 seconds
  void _startPollingPaymentStatus() {
    if (!kIsWeb) {
      debugPrint('⚠️ Not in web mode, skipping polling');
      return;
    }

    debugPrint('🔄 Starting payment polling (5 second interval)...');

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) {
        debugPrint('⚠️ Widget disposed, stopping polling');
        return;
      }

      if (_isProcessingPayment) {
        debugPrint('⚠️ Already processing, skipping this poll');
        _startPollingPaymentStatus(); // Continue polling
        return;
      }

      debugPrint('🔄 === POLLING ITERATION ===');
      debugPrint('🔄 Checking payment status...');

      _verifyPaymentStatus()
          .then((_) {
            // Continue polling if still needed
            if (mounted && !_isProcessingPayment) {
              debugPrint('🔄 Scheduling next poll...');
              _startPollingPaymentStatus();
            } else {
              debugPrint('✅ Polling stopped (processing complete)');
            }
          })
          .catchError((error) {
            debugPrint('❌ Polling error: $error');
            if (mounted) {
              _startPollingPaymentStatus(); // Continue even on error
            }
          });
    });
  }

  // MOBILE: Check payment status from URL
  void _checkPaymentStatus(String url) {
    debugPrint('🔍 Checking URL: $url');

    if (url.contains('status_code=200') ||
        url.contains('transaction_status=settlement') ||
        url.contains('transaction_status=capture') ||
        url.contains('/finish') ||
        (url.contains('?order_id=') && url.contains('status_code'))) {
      if (_isProcessingPayment) return;

      _isProcessingPayment = true;
      debugPrint('✅ SUCCESS detected!');

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _verifyPaymentStatus();
      });
    } else if (url.contains('status_code=201') ||
        url.contains('transaction_status=pending')) {
      debugPrint('⏳ Payment pending...');
    } else if (url.contains('status_code=202') ||
        url.contains('transaction_status=deny') ||
        url.contains('transaction_status=cancel') ||
        url.contains('transaction_status=expire') ||
        url.contains('/unfinish') ||
        url.contains('/error')) {
      if (!_isProcessingPayment) {
        _isProcessingPayment = true;
        debugPrint('❌ FAILURE detected!');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _handlePaymentFailure();
        });
      }
    }
  }

  // ⭐ FUNGSI: Mengurangi stok produk setelah pembayaran berhasil
  Future<void> _reduceProductStock() async {
    if (_token == null) {
      debugPrint('⚠️ No token, skipping stock reduction');
      return;
    }

    try {
      debugPrint('📦 Reducing product stock...');

      // Siapkan data items untuk pengurangan stok
      final items = widget.cartItems.map((item) {
        final productId =
            item['produkId'] ??
            item['produk_id'] ??
            item['product_id'] ??
            item['id'];
        final size = item['size'] ?? item['ukuran'] ?? '';
        final quantity = item['quantity'] ?? item['jumlah'] ?? 1;

        return {
          'productId': productId?.toString() ?? '',
          'size': size.toString(),
          'quantity': int.tryParse(quantity.toString()) ?? 1,
        };
      }).toList();

      debugPrint('📦 Items to reduce: ${jsonEncode(items)}');

      final uri = Uri.parse('$baseUrl/inventory/reduce-stock');

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'items': items}),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 Stock reduction response: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Stock reduced successfully');
        debugPrint('✅ Results: ${data['results']}');

        if (data['errors'] != null && (data['errors'] as List).isNotEmpty) {
          debugPrint('⚠️ Some items had errors: ${data['errors']}');
        }
      } else {
        debugPrint('⚠️ Failed to reduce stock: ${response.statusCode}');
        debugPrint('⚠️ Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error reducing stock: $e');
      // Tidak throw error karena pembayaran sudah berhasil
    }
  }

  // ⭐ VERIFY: Cek status pembayaran dan update order
  Future<void> _verifyPaymentStatus() async {
    if (transactionToken == null || _orderId == null) {
      debugPrint('⚠️ Missing token or orderId');
      _isProcessingPayment = false;
      return;
    }

    // Prevent multiple simultaneous checks
    if (_isProcessingPayment) {
      debugPrint('⚠️ Already processing payment, skipping...');
      return;
    }

    _isProcessingPayment = true;

    try {
      debugPrint('🔍 ========== VERIFYING PAYMENT ==========');
      debugPrint('🔍 Order ID: $_orderId');
      debugPrint(
        '🔍 Transaction Token: ${transactionToken?.substring(0, 20)}...',
      );

      final url = Uri.parse('$midtransUrl/check-status');
      debugPrint('🔍 Midtrans URL: $url');

      // ⭐ PERBAIKAN: Kirim "orderId" (camelCase) sesuai server
      final requestBody = {"orderId": _orderId};
      debugPrint('🔍 Request Body: ${jsonEncode(requestBody)}');

      final response = await http
          .post(
            url,
            headers: {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 ========== RESPONSE ==========');
      debugPrint('📥 Status Code: ${response.statusCode}');
      debugPrint('📥 Response Headers: ${response.headers}');
      debugPrint('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactionStatus = data['transaction_status'];
        final paymentType = data['payment_type'] ?? 'unknown';

        debugPrint('📊 Transaction Status: $transactionStatus');
        debugPrint('📊 Payment Type: $paymentType');

        switch (transactionStatus) {
          case 'capture':
          case 'settlement':
            debugPrint('✅ ========== PAYMENT SUCCESS ==========');

            // 1. Update order status ke 'paid'
            debugPrint('📝 Step 1: Updating order status...');
            await _updateOrderStatus('paid', paymentType);

            // 2. Kurangi stok produk
            debugPrint('📦 Step 2: Reducing stock...');
            await _reduceProductStock();

            // 3. Hapus cart
            debugPrint('🧹 Step 3: Clearing cart...');
            await _clearCart();

            // 4. Redirect ke success page
            debugPrint('🎉 Step 4: Redirecting to success page...');
            if (mounted) {
              _handlePaymentSuccess();
            }
            break;

          case 'pending':
            debugPrint('⏳ Payment still pending...');
            await _updateOrderStatus('pending', paymentType);
            _isProcessingPayment = false;
            break;

          case 'deny':
          case 'expire':
          case 'cancel':
            debugPrint('❌ Payment failed: $transactionStatus');
            await _updateOrderStatus('failed', paymentType);
            if (mounted) {
              _handlePaymentFailure();
            }
            break;

          default:
            debugPrint('⚠️ Unknown status: $transactionStatus');
            _isProcessingPayment = false;
        }
      } else if (response.statusCode == 400) {
        debugPrint('❌ ========== BAD REQUEST (400) ==========');
        debugPrint('❌ Midtrans rejected the request');
        debugPrint('❌ Response body: ${response.body}');

        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          debugPrint('❌ Error details: $errorData');
        } catch (e) {
          debugPrint('❌ Raw error: ${response.body}');
        }

        _isProcessingPayment = false;
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ Transaction not found yet (404), will retry...');
        _isProcessingPayment = false;
      } else {
        debugPrint('❌ Unexpected response: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.body}');
        _isProcessingPayment = false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ========== VERIFY ERROR ==========');
      debugPrint('❌ Error: $e');
      debugPrint(
        '❌ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}',
      );
      _isProcessingPayment = false;
    }
  }

  Future<void> _updateOrderStatus(
    String status, [
    String? paymentMethod,
  ]) async {
    if (_orderDbId == null) {
      debugPrint('⚠️ No DB ID, cannot update status');
      return;
    }

    try {
      debugPrint('📝 Updating order status to: $status');
      debugPrint('📝 Order DB ID: $_orderDbId');

      final uri = Uri.parse('$baseUrl/orders/$_orderDbId');

      final response = await http
          .put(
            uri,
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'status': status,
              'payment_method': paymentMethod,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📥 Update status response: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('✅ Order status updated to: $status');
      } else {
        debugPrint('⚠️ Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error updating order: $e');
    }
  }

  Future<void> _deleteOrder() async {
    if (_orderDbId == null) return;

    try {
      debugPrint('🗑️ Deleting order: $_orderDbId');

      await http
          .delete(
            Uri.parse('$baseUrl/orders/$_orderDbId'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ Order deleted');
      _orderCreated = false;
    } catch (e) {
      debugPrint('❌ Error deleting: $e');
    }
  }

  Future<void> _clearCart() async {
    try {
      debugPrint('🧹 Clearing cart...');
      int successCount = 0;
      int errorCount = 0;

      for (var item in widget.cartItems) {
        try {
          final cartId = item['id']?.toString();
          if (cartId != null && cartId.isNotEmpty) {
            final response = await http
                .delete(
                  Uri.parse('$baseUrl/cart/$cartId'),
                  headers: {'Authorization': 'Bearer $_token'},
                )
                .timeout(const Duration(seconds: 5));

            if (response.statusCode == 200) {
              successCount++;
              debugPrint('✅ Cart item $cartId deleted');
            } else {
              errorCount++;
              debugPrint(
                '⚠️ Failed to delete cart item $cartId: ${response.statusCode}',
              );
            }
          }
        } catch (e) {
          errorCount++;
          debugPrint('❌ Error deleting cart item: $e');
        }
      }

      debugPrint('✅ Cart cleared: $successCount success, $errorCount errors');
    } catch (e) {
      debugPrint('❌ Error clearing cart: $e');
    }
  }

  void _handlePaymentSuccess() {
    if (!mounted) return;

    debugPrint('🎉 Navigating to success page...');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentSuccessPage(
          orderId: _orderId ?? '',
          customerName: widget.name,
          totalAmount: widget.totalHarga.toInt(),
        ),
      ),
    );
  }

  void _handlePaymentFailure() {
    if (!mounted) return;

    debugPrint('💔 Payment failed');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Pembayaran Gagal"),
        content: const Text("Pembayaran gagal atau dibatalkan."),
        actions: [
          TextButton(
            onPressed: () async {
              if (_orderCreated) await _deleteOrder();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text("Kembali"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                isLoading = true;
                errorMessage = null;
                _isProcessingPayment = false;
                transactionToken = null;
              });
              _createMidtransTransaction();
            },
            child: const Text("Coba Lagi"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBackToShipping() async {
    if (_orderCreated) await _deleteOrder();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Batalkan Pembayaran?"),
            content: const Text("Order akan dibatalkan. Yakin?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Tidak"),
              ),
              TextButton(
                onPressed: () async {
                  await _handleBackToShipping();
                  Navigator.pop(context, true);
                },
                child: const Text("Ya"),
              ),
            ],
          ),
        );
        return shouldPop ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Pembayaran"),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Batalkan?"),
                  content: const Text("Order akan dibatalkan."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Tidak"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Ya"),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _handleBackToShipping();
              }
            },
          ),
        ),
        body: Stack(
          children: [
            // Mobile WebView
            if (!kIsWeb && _controller != null)
              WebViewWidget(controller: _controller!),

            // Web View
            if (kIsWeb) _buildWebPaymentView(),

            // Loading indicator
            if (isLoading && errorMessage == null && !kIsWeb)
              Container(
                color: Colors.white.withOpacity(0.95),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'Memuat halaman pembayaran...',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            // Error view
            if (errorMessage != null)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Terjadi Kesalahan',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.arrow_back, size: 18),
                            label: const Text("Kembali"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Colors.black),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () async {
                              await _handleBackToShipping();
                            },
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text("Coba Lagi"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                isLoading = true;
                                errorMessage = null;
                                _isProcessingPayment = false;
                              });
                              _startPaymentProcess();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Web-specific UI
  Widget _buildWebPaymentView() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.payment, size: 80, color: Colors.black),
              const SizedBox(height: 24),
              Text(
                _paymentWindowOpened
                    ? 'Halaman Pembayaran Dibuka'
                    : 'Membuka Halaman Pembayaran...',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _paymentWindowOpened
                    ? 'Silakan selesaikan pembayaran di tab/window yang baru dibuka.\n\nStatus pembayaran akan otomatis diperbarui setiap 5 detik.'
                    : 'Mohon tunggu...',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_paymentWindowOpened) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
                const SizedBox(height: 16),
                Text(
                  _isProcessingPayment
                      ? 'Memproses pembayaran...'
                      : 'Menunggu konfirmasi pembayaran...',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Manual check button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  onPressed: _isProcessingPayment
                      ? null
                      : () {
                          debugPrint('🔄 Manual check triggered by user');
                          setState(() {
                            _isProcessingPayment = false; // Reset flag
                          });
                          _verifyPaymentStatus();
                        },
                  icon: const Icon(Icons.refresh, size: 24),
                  label: const Text(
                    'Cek Status Pembayaran',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 16),

                // Info text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.blue,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Jika pembayaran sudah berhasil di Midtrans tapi status tidak berubah, klik tombol "Cek Status Pembayaran" di atas.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Back button
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Batalkan Pembayaran?'),
                        content: const Text(
                          'Jika Anda membatalkan sekarang, order akan dihapus. Pastikan pembayaran belum berhasil.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Tidak'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Ya, Batalkan'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _handleBackToShipping();
                    }
                  },
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Kembali'),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('🔚 Payment page disposed');
    _controller = null;
    super.dispose();
  }
}
