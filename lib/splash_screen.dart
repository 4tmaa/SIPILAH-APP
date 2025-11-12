// lib/splash_screen.dart
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: Column( 
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Image.asset( 
                  'assets/images/icon.gif', 
                  width: 150, 
                  height: 150, 
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 150, color: Colors.red),
                ),
                const SizedBox(height: 1), 
                Image.asset(
                  'assets/images/sipilah_logo_text1.png',
                  width: 250,
                ),
                const SizedBox(height: 1),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Image.asset('assets/images/logo-amikom.png', height: 50, errorBuilder: (c, e, s) => const Icon(Icons.image, size: 50, color: Colors.grey)),
                Image.asset('assets/images/Logo-Tut-Wuri-Handayani-PNG-Warna.png', height: 50, errorBuilder: (c, e, s) => const Icon(Icons.image, size: 50, color: Colors.grey)),
                Image.asset('assets/images/Logo-Tersier-Diktisaintek-Berdampak.png', height: 50, errorBuilder: (c, e, s) => const Icon(Icons.image, size: 50, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}