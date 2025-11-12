// lib/faqs_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Untuk kBackgroundGradient

class FaqsPage extends StatelessWidget {
  const FaqsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: kBackgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      "FAQs",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // List of FAQs
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    _buildFaqItem(
                      question: "Apa itu SIPILAH?",
                      answer:
                          "SIPILAH adalah singkatan dari Sistem Pintar Irigasi Lahan. Aplikasi ini dirancang untuk membantu Anda mengontrol dan memantau sistem irigasi untuk lahan atau kebun Anda dari jarak jauh melalui smartphone.",
                    ),
                    _buildFaqItem(
                      question: "Bagaimana cara mengaktifkan pompa air?",
                      answer:
                          "Di halaman utama (Home), temukan kartu 'Pompa Air'. Cukup tekan tombol saklar (toggle) ke posisi ON untuk mengaktifkannya. Tekan kembali untuk mematikannya.",
                    ),
                    _buildFaqItem(
                      question: "Apakah saya bisa mengubah nama lahan?",
                      answer:
                          "Saat ini, fitur untuk mengubah nama lahan ('Lahan 1', 'Lahan 2', dll.) belum tersedia, namun akan ditambahkan pada pembaruan aplikasi selanjutnya.",
                    ),
                    _buildFaqItem(
                      question: "Mengapa data sensor saya tidak muncul?",
                      answer:
                          "Halaman data sensor saat ini masih dalam tahap pengembangan dan ditandai sebagai 'Coming Soon'. Fitur ini akan segera hadir untuk menampilkan data suhu, kelembaban, dan level air secara real-time.",
                    ),
                    _buildFaqItem(
                      question: "Bagaimana cara melihat riwayat penyiraman?",
                      answer:
                          "Anda dapat melihat riwayat penyiraman harian pada halaman 'Analysis'. Halaman ini menampilkan catatan aktivitas penyiraman yang telah dilakukan.",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for a single FAQ item
  Widget _buildFaqItem({required String question, required String answer}) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
        children: <Widget>[
          Text(answer, textAlign: TextAlign.justify),
        ],
      ),
    );
  }
}
