import 'dart:convert';
import 'package:http/http.dart' as http;

Future<Map<String, dynamic>?> getRecommendedSize(
  int weight,
  int age,
  int height,
) async {
  try {
    // Panggil API untuk prediksi ukuran
    final response = await http.post(
      Uri.parse('http://localhost:3000/api/predict-size'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'weight': weight, 'age': age, 'height': height}),
    );

    print('=== API Response ===');
    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Cek apakah response berisi recommended_size
      if (data is Map<String, dynamic>) {
        return data;
      } else {
        return {'error': 'Format response tidak valid'};
      }
    } else if (response.statusCode == 400) {
      final error = jsonDecode(response.body);
      return {'error': error['message'] ?? 'Input tidak valid'};
    } else {
      return {
        'error':
            'Gagal mendapatkan rekomendasi ukuran (${response.statusCode})',
      };
    }
  } catch (e) {
    print('=== Exception in getRecommendedSize ===');
    print('Error: $e');
    return {'error': 'Terjadi kesalahan: $e'};
  }
}
