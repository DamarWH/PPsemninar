// lib/main.dart
import 'package:batiksekarniti/login.dart';
import 'package:batiksekarniti/register.dart';
import 'package:batiksekarniti/splashscreen.dart';
import 'package:batiksekarniti/widgets/bottom_navbar.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Batik Sekarniti',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      initialRoute: "/splash",
      routes: {
        "/splash": (context) => const SplashScreen(),
        LoginPage.id: (context) => LoginPage(),
        RegisterPage.id: (context) => RegisterPage(),
        // SEMUA user (admin & customer) menggunakan route /home
        // BottomNavBar akan otomatis menampilkan halaman sesuai role
        "/home": (context) => const BottomNavBar(),
      },
    );
  }
}
