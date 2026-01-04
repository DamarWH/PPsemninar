import 'package:flutter/material.dart';

class KonfirmasiTransaksi extends StatelessWidget {
  final String name;
  final String email;
  final String address;
  final String phone;
  final String city;
  final String postalCode;
  final String notes;
  final int totalItems;
  final int totalPrice;
  final List<Map<String, dynamic>> cartItems;

  const KonfirmasiTransaksi({
    super.key,
    required this.name,
    required this.email,
    required this.address,
    required this.phone,
    required this.city,
    required this.postalCode,
    required this.notes,
    required this.totalItems,
    required this.totalPrice,
    required this.cartItems,
  });

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Konfirmasi Pesanan"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============================
          // Informasi Pembeli
          // ============================
          const Text(
            "Informasi Pembeli",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _infoTile("Nama", name),
          _infoTile("Email", email),
          _infoTile("Nomor Telepon", phone),
          _infoTile("Alamat", address),
          _infoTile("Kota/Kecamatan", city),
          _infoTile("Kode Pos", postalCode),
          if (notes.isNotEmpty) _infoTile("Catatan", notes),
          const SizedBox(height: 20),

          // ============================
          // Daftar Produk
          // ============================
          const Text(
            "Daftar Produk",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...cartItems.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: item["foto"] != null && item["foto"] != ""
                    ? Image.network(
                        item["foto"],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image, size: 40),
                title: Text(item["nama"]),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item["ukuran"] != null)
                      Text("Ukuran: ${item["ukuran"]}"),
                    Text("Jumlah: ${item["jumlah"]}"),
                  ],
                ),
                trailing: Text(
                  "Rp ${_formatPrice(item["harga"])}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 20),

          // ============================
          // Ringkasan Pembayaran
          // ============================
          const Text(
            "Ringkasan Pembayaran",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _summaryTile("Total Produk", "$totalItems item"),
          _summaryTile(
            "Total Harga",
            "Rp ${_formatPrice(totalPrice)}",

            isBold: true,
          ),

          const SizedBox(height: 30),

          // ============================
          // TOMBOL BUAT PESANAN (sementara)
          // ============================
          ElevatedButton(
            onPressed: () {
              _showSuccessDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Buat Pesanan",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _summaryTile(String title, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Pesanan Berhasil Dibuat"),
        content: const Text("Pesanan Anda telah disimpan sementara!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}
