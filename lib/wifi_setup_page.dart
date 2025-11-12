// lib/wifi_setup_page.dart
// (GANTI SELURUH ISI FILE DENGAN KODE DI BAWAH INI)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // <-- REVISI: Tambahkan permission_handler
import 'package:flutter_application_1/main.dart'; 

// --- UUID (Tidak Berubah) ---
const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
const String CHAR_UUID_SSID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
const String CHAR_UUID_PASS = "beb5483e-36e1-4688-b7f5-ea07361b26a9";
const String CHAR_UUID_CMD = "beb5483e-36e1-4688-b7f5-ea07361b26aa";
const String TARGET_DEVICE_NAME = "SIPILAH_SETUP";
// ------------------------------------

// --- REVISI: Buat enum untuk mengelola Status Halaman ---
enum SetupStatus {
  idle, // Halaman awal, siap untuk cek
  checking, // Sedang mengecek Bluetooth/Lokasi
  requiresPermission, // Bluetooth/Lokasi mati atau izin ditolak
  readyToScan, // Semua siap, tombol "Mulai Pindai" muncul
  scanning, // Sedang memindai...
  connecting, // Menghubungkan ke perangkat...
  connected, // Terhubung! Siap isi form WiFi
  sending, // Sedang mengirim data WiFi...
  error, // Terjadi error
}
// --- Akhir Revisi ---


class WifiSetupPage extends StatefulWidget {
  const WifiSetupPage({Key? key}) : super(key: key);

  @override
  _WifiSetupPageState createState() => _WifiSetupPageState();
}

class _WifiSetupPageState extends State<WifiSetupPage> {
  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _ssidChar;
  BluetoothCharacteristic? _passChar;
  BluetoothCharacteristic? _cmdChar;

  // --- REVISI: Ganti boolean dengan enum Status ---
  SetupStatus _status = SetupStatus.idle;
  String _statusMessage = "Silakan aktifkan Bluetooth & Lokasi untuk memulai.";
  // --- Akhir Revisi ---

  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  
  // --- REVISI: Tampung state Bluetooth ---
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription? _adapterStateSubscription;

  @override
  void initState() {
    super.initState();
    // --- REVISI: Jangan langsung scan. Cek dulu. ---
    // Dengarkan perubahan status Bluetooth
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      if (state == BluetoothAdapterState.on) {
        // Jika user baru menyalakan Bluetooth, cek ulang
        _checkPrerequisites();
      } else {
        // Jika user mematikan Bluetooth, reset ke halaman awal
        setState(() {
          _status = SetupStatus.requiresPermission;
          _statusMessage = "Silakan nyalakan Bluetooth Anda.";
        });
      }
    });
    // Panggil pengecekan pertama kali
    _checkPrerequisites();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _adapterStateSubscription?.cancel(); // <-- REVISI
    if (_status == SetupStatus.connected || _status == SetupStatus.connecting) {
      _targetDevice?.disconnect();
    }
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  // --- REVISI: Fungsi baru untuk mengecek Bluetooth dan Lokasi ---
  Future<void> _checkPrerequisites() async {
    setState(() {
      _status = SetupStatus.checking;
      _statusMessage = "Memeriksa Bluetooth & Izin Lokasi...";
    });

    // 1. Cek Status Bluetooth Adapter
    if (_adapterState != BluetoothAdapterState.on) {
      setState(() {
        _status = SetupStatus.requiresPermission;
        _statusMessage = "Bluetooth HP Anda belum menyala.";
      });
      return;
    }

    // 2. Cek (dan minta) Izin Lokasi
    var locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      setState(() {
        _status = SetupStatus.requiresPermission;
        _statusMessage = "Aplikasi ini memerlukan Izin Lokasi untuk memindai perangkat.";
      });
      return;
    }
    
    // 3. Cek (dan minta) Izin Bluetooth (Untuk Android 12+)
    var scanStatus = await Permission.bluetoothScan.request();
    var connectStatus = await Permission.bluetoothConnect.request();
    
    if (!scanStatus.isGranted || !connectStatus.isGranted) {
       setState(() {
        _status = SetupStatus.requiresPermission;
        _statusMessage = "Aplikasi ini memerlukan Izin Bluetooth untuk terhubung ke alat.";
      });
      return;
    }

    // Jika semua siap
    setState(() {
      _status = SetupStatus.readyToScan;
      _statusMessage = "Semua siap. Tekan tombol untuk memindai alat.";
    });
  }
  // --- Akhir Revisi ---

  void _stopScan() {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();
    // Jangan ubah status jika bukan sedang scanning (mungkin sudah timeout)
    if (_status == SetupStatus.scanning) {
      setState(() {
        _status = SetupStatus.error;
        _statusMessage = "Gagal menemukan perangkat $TARGET_DEVICE_NAME. Pastikan alat menyala dan dekat dengan HP.";
      });
    }
  }

  void _startScan() {
    // --- REVISI: Tidak perlu cek Bluetooth lagi, sudah di handle ---
    setState(() {
      _status = SetupStatus.scanning;
      _statusMessage = "Mencari perangkat $TARGET_DEVICE_NAME...";
    });

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == TARGET_DEVICE_NAME) {
          _stopScan();
          _targetDevice = r.device;
          _connectToDevice();
          break; 
        }
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    
    // Handle jika scan timeout
    Future.delayed(const Duration(seconds: 16), () {
        if (_status == SetupStatus.scanning) {
            _stopScan();
        }
    });
  }

  void _connectToDevice() async {
    if (_targetDevice == null) return;

    setState(() {
      _status = SetupStatus.connecting;
      _statusMessage = "Menyambungkan ke perangkat...";
    });

    _connectionSubscription =
        _targetDevice!.connectionState.listen((BluetoothConnectionState state) {
      if (state == BluetoothConnectionState.disconnected) {
        // Hanya set error jika kita tidak sedang mengirim data (karena kirim data bisa memicu restart)
        if (_status != SetupStatus.sending) {
          setState(() {
            _status = SetupStatus.error;
            _statusMessage = "Koneksi terputus. Silakan coba lagi.";
          });
        }
      }
    });

    try {
      await _targetDevice!.connect();
      setState(() {
        _status = SetupStatus.connected;
        _statusMessage = "Terhubung. Mencari service...";
      });

      List<BluetoothService> services =
          await _targetDevice!.discoverServices();
      var service = services.firstWhere(
          (s) => s.uuid.str.toLowerCase() == SERVICE_UUID.toLowerCase());

      _ssidChar = service.characteristics.firstWhere(
          (c) => c.uuid.str.toLowerCase() == CHAR_UUID_SSID.toLowerCase());
      _passChar = service.characteristics.firstWhere(
          (c) => c.uuid.str.toLowerCase() == CHAR_UUID_PASS.toLowerCase());
      _cmdChar = service.characteristics.firstWhere(
          (c) => c.uuid.str.toLowerCase() == CHAR_UUID_CMD.toLowerCase());

      if (_ssidChar != null && _passChar != null && _cmdChar != null) {
        setState(() {
          _statusMessage = "Perangkat siap. Silakan masukkan data WiFi.";
        });
      } else {
        throw Exception("Karakteristik tidak ditemukan.");
      }
    } catch (e) {
      setState(() {
        _status = SetupStatus.error;
        _statusMessage = "Error: Gagal menemukan service di alat.";
      });
      _targetDevice?.disconnect();
    }
  }

  void _sendWifiCredentials() async {
    if (_ssidChar == null || _passChar == null || _cmdChar == null) return;

    if (_ssidController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("SSID dan Password tidak boleh kosong.")));
      return;
    }

    setState(() {
      _status = SetupStatus.sending;
      _statusMessage = "Mengirim data ke perangkat...";
    });

    try {
      List<int> ssidBytes = utf8.encode(_ssidController.text);
      await _ssidChar!.write(ssidBytes);
      await Future.delayed(const Duration(milliseconds: 100)); 

      List<int> passBytes = utf8.encode(_passwordController.text);
      await _passChar!.write(passBytes);
      await Future.delayed(const Duration(milliseconds: 100));

      List<int> cmdBytes = utf8.encode("SAVE");
      await _cmdChar!.write(cmdBytes);

      setState(() {
        _statusMessage =
            "Data terkirim! Perangkat akan me-restart dan terhubung ke WiFi.";
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            "Berhasil! Perangkat akan restart. Silakan kembali ke halaman utama."),
        backgroundColor: Colors.green,
      ));
      
      // Tunggu sebentar lalu kembali
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });

    } catch (e) {
      setState(() {
        _status = SetupStatus.error;
        _statusMessage = "Gagal mengirim: ${e.toString()}";
      });
    }
  }
  
  // --- REVISI: Pisahkan UI berdasarkan Status ---
  
  // Widget untuk halaman instruksi awal
  Widget _buildInstructionUI() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey.shade700),
            const SizedBox(height: 24),
            const Text(
              "Aktifkan Bluetooth & Lokasi",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Untuk menghubungkan aplikasi ke Kotak Alat Pintar, Anda perlu:",
              style: TextStyle(fontSize: 16, color: Colors.grey.shade800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.bluetooth, color: Colors.blue, size: 30),
              title: const Text("Nyalakan Bluetooth", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Pastikan Bluetooth di HP Anda menyala."),
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red, size: 30),
              title: const Text("Nyalakan Lokasi (GPS)", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Aplikasi perlu izin lokasi untuk bisa memindai perangkat Bluetooth."),
            ),
            const SizedBox(height: 32),
            if (_status == SetupStatus.checking)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
                onPressed: _checkPrerequisites,
                child: const Text("SAYA SUDAH SIAP, CEK LAGI", style: TextStyle(color: Colors.white)),
              ),
            const SizedBox(height: 16),
            Text(_statusMessage, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
  
  // Widget untuk halaman pemindaian
  Widget _buildScanningUI() {
     return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_status == SetupStatus.readyToScan) ...[
            Icon(Icons.bluetooth_searching, size: 80, color: Theme.of(context).primaryColor),
            const SizedBox(height: 24),
            const Text("Siap Memindai", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(_statusMessage, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade800)),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              onPressed: _startScan, 
              child: const Text("MULAI Pindai", style: TextStyle(color: Colors.white)),
            ),
          ] else ...[
            // Status: scanning, connecting, atau error
            const CircularProgressIndicator(strokeWidth: 5, valueColor: AlwaysStoppedAnimation(Colors.blue)),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _status == SetupStatus.error ? Colors.red : Colors.black87),
              ),
            ),
            const SizedBox(height: 32),
            // Tombol Coba Lagi jika Error
            if (_status == SetupStatus.error)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
                onPressed: _checkPrerequisites, // Kembali ke cek awal
                child: const Text("COBA LAGI", style: TextStyle(color: Colors.white)),
              ),
          ]
        ],
      ),
    );
  }
  
  // Widget untuk form pengisian WiFi
  Widget _buildConnectedFormUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green)),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          // Form
          const Text("Masukkan Kredensial WiFi",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _ssidController,
            decoration: InputDecoration(
                labelText: 'Nama WiFi (SSID)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15))),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
                labelText: 'Password WiFi',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15))),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: (_status == SetupStatus.sending) ? null : _sendWifiCredentials,
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30))),
            child: (_status == SetupStatus.sending)
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("SIMPAN & SAMBUNGKAN",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Konfigurasi WiFi Perangkat"),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: kBackgroundGradient),
        // --- REVISI: Tampilkan UI berdasarkan Status ---
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentUI(),
        ),
        // --- Akhir Revisi ---
      ),
    );
  }
  
  // --- REVISI: Widget helper untuk memilih UI yang tampil ---
  Widget _buildCurrentUI() {
    switch (_status) {
      case SetupStatus.idle:
      case SetupStatus.checking:
      case SetupStatus.requiresPermission:
        return _buildInstructionUI(); // Tampilkan halaman instruksi
        
      case SetupStatus.readyToScan:
      case SetupStatus.scanning:
      case SetupStatus.connecting:
      case SetupStatus.error:
        return _buildScanningUI(); // Tampilkan halaman loading/error scan
        
      case SetupStatus.connected:
      case SetupStatus.sending:
        return _buildConnectedFormUI(); // Tampilkan form jika sudah terhubung
    }
  }
  // --- Akhir Revisi ---
}