🌳 SIPILAH (Sistem Pintar Irigasi Lahan)

<p align="center">
<img src="https://www.google.com/search?q=https://placehold.co/200x200/FFFFFF/000000%3Ftext%3DLogo%2BSIPILAH" alt="Logo SIPILAH" width="200"/>
</p>

SIPILAH adalah aplikasi seluler (Flutter) yang dirancang untuk modernisasi dan manajemen sistem irigasi lahan.

Aplikasi ini tidak hanya memungkinkan pengguna untuk mengontrol perangkat irigasi dari jarak jauh, tetapi juga mencakup sistem manajemen kelompok, penjadwalan piket, dan pelaporan tugas yang komprehensif, menjadikannya ideal untuk lahan komunal atau kelompok tani (seperti PKK).

<p align="center">
<img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
<img src="https://www.google.com/search?q=https://img.shields.io/badge/Dart-0175C2%3Fstyle%3Dfor-the-badge%26logo%3Ddart%26logoColor%3Dwhite" alt="Dart">
</p>

🚀 Fitur Utama

Aplikasi seluler ini dibangun dengan Flutter dan dilengkapi dengan berbagai fitur canggih:

1. Kontrol & Pemantauan

Kontrol 4-Channel: Kontrol 4 relay terpisah secara real-time (Pompa Air, Lahan 1, Lahan 2, Lahan 3) langsung dari dashboard.

Perintah Suara: Gunakan fitur Speech-to-Text (STT) untuk mengontrol relay menggunakan perintah suara dalam Bahasa Indonesia.

Dashboard Cuaca: Menampilkan cuaca, suhu, dan lokasi pengguna saat ini menggunakan API OpenWeatherMap.

2. Autentikasi & Manajemen Pengguna

Otentikasi Multi-Platform: Pengguna dapat mendaftar/login menggunakan Email/Password, Google Sign-In, atau Facebook Login.

Manajemen Profil: Pengguna dapat memperbarui nama dan detail profil mereka.

3. Manajemen Kelompok & Penjadwalan (Fitur Canggih)

Sistem Grup: Pengguna dapat membuat grup baru atau bergabung dengan grup yang ada menggunakan kode gabung (join code) unik.

Jadwal Piket Global: Menampilkan jadwal piket mingguan untuk semua kelompok yang terdaftar di aplikasi.

Otoritas Edit Terbatas: Anggota kelompok only dapat mengedit jadwal piket untuk kelompok mereka sendiri. Jadwal kelompok lain bersifat read-only (hanya bisa dilihat).

4. Pelaporan & Analisis

Checklist Tugas Harian: Sistem pelaporan tugas harian yang dibagi menjadi 3 kategori: Individu, Kelompok, dan Mingguan.

Logika Cooldown & Kunci: Tugas mingguan memiliki cooldown 7 hari, dan tugas kelompok terkunci untuk semua anggota setelah satu orang menyelesaikannya.

Riwayat (Analisis): Halaman analisis mendalam untuk melihat riwayat penyiraman dan penyelesaian tugas, lengkap dengan filter berdasarkan tanggal (Harian, Mingguan, Bulanan) dan jenis.

Privasi Data: Halaman analisis menampilkan data lengkap (nama pengguna & grup) untuk kelompok sendiri, namun menganonimkan (hanya menampilkan nama grup) untuk riwayat kelompok lain.

Tarik untuk Segarkan: Pull-to-refresh diimplementasikan di halaman Laporan dan Pengaturan untuk memastikan data selalu baru.

🔧 Tumpukan Teknologi (Tech Stack)

Framework: Flutter

Bahasa: Dart

State Management: setState (digunakan di seluruh proyek)

Perpustakaan Kunci:

firebase_core, firebase_auth, firebase_database (Konektivitas Backend)

google_sign_in, flutter_facebook_auth (Login Sosial)

speech_to_text (Perintah Suara)

geolocator, http (API Cuaca)

permission_handler (Pengecekan Izin)

🖼️ Tangkapan Layar (Screenshots)

Halaman Login

Dashboard Utama

Perintah Suara

[Gambar Halaman Login]

[Gambar Dashboard Utama]

[Gambar Perintah Suara]

Laporan Tugas Harian

Analisis Riwayat

Manajemen Grup

[Gambar Laporan Tugas Harian]

[Gambar Analisis Riwayat]

[Gambar Manajemen Grup]

(Silakan ganti teks [Gambar ...] dengan tangkapan layar asli Anda)

🛠️ Petunjuk Penyiapan Aplikasi

Kloning Repositori

git clone [https://github.com/4tmaa/SIPILAH-APP.git](https://github.com/4tmaa/SIPILAH-APP.git)
cd SIPILAH-APP


Konfigurasi Kredensial

Aplikasi ini memerlukan koneksi ke backend (seperti Firebase) dan API (seperti Facebook Login) agar dapat berfungsi.

Pastikan Anda memiliki file google-services.json di android/app/.

Pastikan AndroidManifest.xml dan strings.xml Anda telah dikonfigurasi dengan kredensial Facebook App ID dan Secret.

Install Dependencies
Jalankan perintah ini di terminal:

flutter pub get


Jalankan Aplikasi
Hubungkan perangkat atau emulator Anda, lalu jalankan:

flutter run
