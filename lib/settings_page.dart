// lib/settings_page.dart
// (GANTI SELURUH ISI FILE DENGAN KODE DI BAWAH INI)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/faqs_page.dart';
import 'package:flutter_application_1/group_management_page.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/user_profile_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/wifi_setup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- REVISI 1: Tambahkan controller untuk key ---
  final _wifiKeyController = TextEditingController();

  // Kunci unik bisa Anda ubah di sini
  final String _uniqueWifiKey = "SIPILAH_ADMIN_2025";
  // --- Akhir Revisi 1 ---

  // Variabel yang ada
  User? currentUser = FirebaseAuth.instance.currentUser;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _wifiKeyController.dispose(); // Jangan lupa dispose
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- REVISI 2: Fungsi untuk Refresh Halaman ---
  // Ini akan memuat ulang data pengguna saat ini
  Future<void> _refreshUserData() async {
    await FirebaseAuth.instance.currentUser?.reload();
    setState(() {
      currentUser = FirebaseAuth.instance.currentUser;
    });
  }
  // --- Akhir Revisi 2 ---

  // --- REVISI 3: Perbaikan Fungsi Email ---
  Future<void> _launchEmail() async {
    final String email = 'sipilahsmartfarm@gmail.com';
    final String subject = 'Bantuan Aplikasi SIPILAH';
    final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=${Uri.encodeComponent(subject)}');

    try {
      // Kita paksa buka di aplikasi eksternal, ini lebih stabil
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tidak dapat menemukan aplikasi email.")));
      }
    }
  }
  // --- Akhir Revisi 3 ---

  // --- REVISI 4: Fungsi untuk menampilkan dialog Unique Key ---
  Future<void> _showWifiAccessDialog() async {
    // Reset controller setiap kali dialog dibuka
    _wifiKeyController.clear();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Akses Terbatas'),
          content: TextField(
            controller: _wifiKeyController,
            autofocus: true,
            decoration:
                const InputDecoration(hintText: "Masukkan Unique Key"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Batal'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Buka'),
              onPressed: () {
                // Ambil input dan cek
                final String inputKey = _wifiKeyController.text.trim();
                Navigator.of(dialogContext).pop(); // Tutup dialog

                if (inputKey == _uniqueWifiKey) {
                  // Jika Kunci Benar: Buka Halaman WiFi Setup
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const WifiSetupPage()));
                } else {
                  // Jika Kunci Salah: Tampilkan Pesan Error
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Key Salah! Akses ditolak."),
                    backgroundColor: Colors.red,
                  ));
                }
              },
            ),
          ],
        );
      },
    );
  }
  // --- Akhir Revisi 4 ---

  // --- (Fungsi _changePassword dan _showChangePasswordSheet tidak berubah) ---
  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    if (newPassword != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Password baru tidak cocok."),
          backgroundColor: Colors.red));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    final cred =
        EmailAuthProvider.credential(email: user!.email!, password: currentPassword);
    try {
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Password berhasil diubah."),
          backgroundColor: Colors.green));
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message ?? "Gagal mengubah password."),
          backgroundColor: Colors.red));
    }
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 24,
            right: 24),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25), topRight: Radius.circular(25))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ubah Kata Sandi",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                    hintText: 'Kata Sandi Saat Ini',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300)))),
            const SizedBox(height: 15),
            TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                    hintText: 'Kata Sandi Baru',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300)))),
            const SizedBox(height: 15),
            TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                    hintText: 'Konfirmasi Kata Sandi',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey.shade300)))),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _changePassword,
                child: const Text("SAVE",
                    style:
                        TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30))),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: kBackgroundGradient),
        // --- REVISI 5: Tambahkan RefreshIndicator ---
        child: RefreshIndicator(
          onRefresh: _refreshUserData,
          child: SafeArea(
            child: SingleChildScrollView(
              // Pastikan bisa di-scroll agar refresh selalu aktif
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Settings",
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildWelcomeCard(),
                  const SizedBox(height: 30),
                  _buildSettingsList(),
                  const SizedBox(height: 30),
                  _buildInfoBox(),
                  const SizedBox(height: 40),
                  _buildSocialLogos(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
        // --- Akhir Revisi 5 ---
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Welcome,", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                  // Gunakan variabel currentUser yang bisa di-refresh
                  currentUser?.displayName ??
                      currentUser?.email?.split('@')[0] ??
                      "Pengguna",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)
          ]),
      child: Column(
        children: [
          _buildSettingsItem(
            icon: Icons.person_outline,
            title: "User Profile",
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const UserProfilePage())
              // --- REVISI 6: Panggil refresh setelah kembali ---
              ).then((_) => _refreshUserData()); // <-- TAMBAHKAN INI
            },
          ),
          const Divider(indent: 20, endIndent: 20),
          _buildSettingsItem(
            icon: Icons.group_work_outlined,
            title: "Manajemen Kelompok",
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GroupManagementPage()));
            },
          ),
          const Divider(indent: 20, endIndent: 20),

          // --- REVISI 7: Ubah onTap untuk WiFi Setup ---
          _buildSettingsItem(
            icon: Icons.wifi,
            title: "Konfigurasi WiFi Perangkat",
            onTap: () {
              // Panggil dialog, bukan navigasi langsung
              _showWifiAccessDialog();
            },
          ),
          // --- Akhir Revisi 7 ---

          const Divider(indent: 20, endIndent: 20),
          _buildSettingsItem(
            icon: Icons.lock_outline,
            title: "Ubah Kata Sandi",
            onTap: () {
              _showChangePasswordSheet(context);
            },
          ),
          const Divider(indent: 20, endIndent: 20),
          _buildSettingsItem(
            icon: Icons.help_outline,
            title: "FAQs",
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const FaqsPage()));
            },
          ),
        ],
      ),
    );
  }

  // --- (Widget sisanya tidak berubah) ---
  Widget _buildSettingsItem(
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade600),
            const SizedBox(width: 15),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLogos() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSocialLogo('assets/images/logo-amikom.png'),
        _buildSocialLogo('assets/images/Logo-Tut-Wuri-Handayani-PNG-Warna.png'),
        _buildSocialLogo(
            'assets/images/Logo-Tersier-Diktisaintek-Berdampak.png'),
      ],
    );
  }

  Widget _buildSocialLogo(String assetPath) {
    return Image.asset(
      assetPath,
      width: 40,
      height: 40,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.image_not_supported,
              color: Colors.grey.shade600, size: 20),
        );
      },
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(child: Text("Jika ada pertanyaan, hubungi kami.")),
          TextButton(
            child: const Text("Email Kami",
                style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _launchEmail, // Panggil fungsi yang sudah diperbaiki
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor),
          )
        ],
      ),
    );
  }
}