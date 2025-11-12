#  SIPILAH: Sistem Pintar Irigasi Lahan

<p align="center">
  <img src="assets/images/sipilah_logo.png" alt="Logo SIPILAH" width="200"/>
</p>

<p align="center">
  SIPILAH adalah solusi Internet of Things (IoT) lengkap yang dirancang untuk modernisasi sistem irigasi lahan. Proyek ini menggabungkan aplikasi seluler (Flutter) dengan perangkat keras (ESP32) yang terhubung secara real-time melalui Firebase. Aplikasi ini tidak hanya memungkinkan pengguna untuk mengontrol perangkat irigasi dari jarak jauh, tetapi juga mencakup sistem manajemen kelompok, penjadwalan piket, dan pelaporan tugas yang komprehensif, menjadikannya ideal untuk lahan komunal atau kelompok tani (seperti PKK).
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase">
</p>

---

## 📸 Tangkapan Layar (Screenshots)

| Halaman Login | Halaman Utama (Dashboard) |
| :---: | :---: |
| ![Login](https://github.com/user-attachments/assets/e2c33a15-17d1-4ba1-bca0-ecccd6d2cfc2) | ![Home](https://github.com/user-attachments/assets/42dd3e32-d346-4423-b9ef-0e26aa3aabbd) |

| Halaman Report | Halaman Analysis | Halaman Settings |
| :---: | :---: |  :---: |
| ![Report](https://github.com/user-attachments/assets/782099a6-7d21-4a55-bfa4-25ad1b3c0775) | ![Analysis](https://github.com/user-attachments/assets/2237dd3b-c667-43cf-a693-f08c2c31a69a) | ![Settings](https://github.com/user-attachments/assets/a63e76c2-7e44-4bbe-af4b-d1402d8ea548) |

---

## ✨ Fitur Utama

* 📱 **Autentikasi & Manajemen Pengguna**
    Otentikasi Multi-Platform: Pengguna dapat mendaftar/login menggunakan Email/Password, Google Sign-In, atau Facebook Login.
    
    Manajemen Profil: Pengguna dapat memperbarui nama dan detail profil mereka, yang disinkronkan ke Firebase Auth dan Realtime Database.

* 📊 **Pelaporan & Analisis**
    Checklist Tugas Harian: Sistem pelaporan tugas harian yang dibagi menjadi 3 kategori: Individu, Kelompok, dan Mingguan.
    
    Logika Cooldown & Kunci: Tugas mingguan memiliki cooldown 7 hari, dan tugas kelompok terkunci untuk semua anggota setelah satu orang menyelesaikannya.
    
    Riwayat (Analisis): Halaman analisis mendalam untuk melihat riwayat penyiraman dan penyelesaian tugas, lengkap dengan filter berdasarkan tanggal (Harian, Mingguan, Bulanan) dan jenis.
    
    Privasi Data: Halaman analisis menampilkan data lengkap (nama pengguna & grup) untuk kelompok sendiri, namun menganonimkan (hanya menampilkan nama grup) untuk riwayat kelompok lain.
    
    Tarik untuk Segarkan: Pull-to-refresh diimplementasikan di halaman Laporan dan Pengaturan untuk memastikan data selalu baru.

* 💡 **Kontrol & Pemantauan**
    Kontrol 4-Channel: Kontrol 4 relay terpisah secara real-time (Pompa Air, Lahan 1, Lahan 2, Lahan 3) langsung dari dashboard.
    
    Sinkronisasi 2 Arah: Perubahan status melalui tombol fisik pada perangkat ESP32 akan langsung diperbarui di aplikasi (dan sebaliknya).
    
    Perintah Suara: Gunakan fitur Speech-to-Text (STT) untuk mengontrol relay menggunakan perintah suara dalam Bahasa Indonesia.
    
    Dashboard Cuaca: Menampilkan cuaca, suhu, dan lokasi pengguna saat ini menggunakan API OpenWeatherMap.

* 👥 **Manajemen Kelompok & Penjadwalan**
    Sistem Grup: Pengguna dapat membuat grup baru atau bergabung dengan grup yang ada menggunakan kode gabung (join code) unik.
    
    Jadwal Piket Global: Menampilkan jadwal piket mingguan untuk semua kelompok yang terdaftar di aplikasi.
    
    Otoritas Edit Terbatas: Anggota kelompok hanya dapat mengedit jadwal piket untuk kelompok mereka sendiri. Jadwal kelompok lain bersifat read-only (hanya bisa dilihat).

* ⚙️ **Penyiapan Perangkat (Hardware Provisioning)**
    Konfigurasi WiFi via BLE: Pengguna dapat mengatur kredensial WiFi (SSID & Password) pada perangkat ESP32 baru melalui koneksi Bluetooth Low Energy (BLE).
    
    Panduan & Pengecekan Izin: Halaman setup secara cerdas memeriksa apakah Bluetooth & Izin Lokasi sudah aktif sebelum memindai.
    
    Akses Aman: Halaman "Konfigurasi WiFi Perangkat" di dalam aplikasi dilindungi oleh Unique Key (hardcoded) untuk mencegah akses yang tidak sah.Penyiapan Perangkat (Hardware Provisioning)
    Konfigurasi WiFi via BLE: Pengguna dapat mengatur kredensial WiFi (SSID & Password) pada perangkat ESP32 baru melalui koneksi Bluetooth Low Energy (BLE).
    
    Panduan & Pengecekan Izin: Halaman setup secara cerdas memeriksa apakah Bluetooth & Izin Lokasi sudah aktif sebelum memindai.
    
    Akses Aman: Halaman "Konfigurasi WiFi Perangkat" di dalam aplikasi dilindungi oleh Unique Key (hardcoded) untuk mencegah akses yang tidak sah.

---

## 🛠️ Teknologi yang Digunakan

Aplikasi ini dibangun menggunakan teknologi modern:

* **Framework:** Flutter (Cross-platform UI)
* **Bahasa:** Dart
* **Database:** Firebase Realtime Database / Firestore
* **Otentikasi:** Firebase Authentication
---

## 🚀 Cara Menjalankan Proyek (Getting Started)

Berikut adalah langkah-langkah untuk menjalankan proyek ini di komputer Anda.

### 1. Prasyarat (Prerequisites)

* Pastikan Anda sudah menginstal [**Flutter SDK**](https://flutter.dev/docs/get-started/install).
* Memiliki akun [**Firebase**](https://firebase.google.com/).

### 2. Instalasi & Konfigurasi

1.  **Clone Repositori**
    ```bash
    git clone [https://github.com/4tmaa/SIPILAH-APP.git](https://github.com/4tmaa/SIPILAH-APP.git)
    cd SIPILAH-APP
    ```

2.  **Konfigurasi Firebase (PENTING)**
    Proyek ini membutuhkan file konfigurasi Firebase agar terhubung. Karena file ini rahasia, file ini tidak ada di repositori (sudah di-.gitignore).

    * Pergi ke **Firebase Console** Anda.
    * Masuk ke **Project Settings**.
    * Download file `google-services.json` (untuk Android).
    * Tempatkan file tersebut di lokasi: `android/app/google-services.json`.

3.  **Install Dependencies**
    Jalankan perintah ini di terminal:
    ```bash
    flutter pub get
    ```

4.  **Jalankan Aplikasi**
    Hubungkan perangkat atau emulator Anda, lalu jalankan:
    ```bash
    flutter run
    ```

---

## 👤 Kontributor

* **Diky Mulya Atmaja** - @dikymulyaatmaja@gmail.com
