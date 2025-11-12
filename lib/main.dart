// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/auth_gate.dart'; // <-- Impor AuthGate
import 'package:flutter_application_1/firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';
// (Hapus import lain seperti splash_screen, login_page, dll.)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('id_ID', null);
  runApp(const MyApp());
}

// ... (Konstanta Anda kBackgroundGradient, dll. biarkan di sini) ...

const kBackgroundGradient = LinearGradient(
  colors: [Color(0xFFF5F7FA), Color(0xFFE8F5E9)],
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
);
const kCardColor = Colors.white;
const kActiveGradient = LinearGradient(
  colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIPILAH',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.transparent,
        primaryColor: const Color(0xFF2E7D32),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: const Color(0xFF43A047),
          foregroundColor: Colors.white,
        ),
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF333333)),
          bodyLarge: TextStyle(color: Color(0xFF333333)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF43A047),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      debugShowCheckedModeBanner: false,
      
      // INI HARUS AUTHGATE
      home: const AuthGate(),
    );
  }
}