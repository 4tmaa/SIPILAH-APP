// lib/auth_gate.dart (atau di mana pun file ini berada)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ⚠️ GANTI INI: Sesuaikan path impor ke file halaman Anda
import 'package:flutter_application_1/login_page.dart'; // Ganti dengan path login page Anda
import 'package:flutter_application_1/main_navigation_screen.dart'; // Contoh, ganti dengan halaman utama Anda


class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // 1. Saat Firebase sedang memeriksa (menunggu data)...
        if (snapshot.connectionState == ConnectionState.waiting) {
          // ...LANGSUNG tampilkan UI Splash Screen Anda di sini
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

        // 2. Jika Firebase sudah selesai & menemukan data user (login)
        if (snapshot.hasData) {
          // Arahkan ke Halaman Utama
          // ⚠️ GANTI 'MainNavigationScreen()' DENGAN NAMA HALAMAN UTAMA ANDA
          return MainNavigationScreen(); // <-- GANTI INI
        }

        // 3. Jika Firebase sudah selesai & TIDAK menemukan data user
        // Arahkan ke Halaman Login
        // ⚠️ GANTI 'LoginPage()' DENGAN NAMA HALAMAN LOGIN ANDA
        return LoginPage(); // <-- GANTI INI
      },
    );
  }
}