// lib/main_navigation_screen.dart

// --- TAMBAHKAN SEMUA IMPORT INI ---
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/analysis_page.dart';
import 'package:flutter_application_1/settings_page.dart';
import 'package:flutter_application_1/sensor_data_page.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_application_1/main.dart' show kBackgroundGradient, kCardColor, kActiveGradient; // Ambil konstanta
// --- BATAS IMPORT ---

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  _MainNavigationScreenState createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    
    _pages = <Widget>[
      HomePage(onUpdateRelay: _updateRelayStatus),
      SensorDataPage(),
      AnalysisPage(),
      SettingsPage(),
    ];

    // --- PEMANGGILAN _setupFCMListeners() DIHAPUS ---
    _initSpeech(); // Panggil inisialisasi suara di sini
  }

  // --- FUNGSI _setupFCMListeners() DIHAPUS SELURUHNYA ---


  // --- BLOK FUNGSI SUARA (Tetap sama) ---
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (error) => debugPrint('Speech error: $error'),
      onStatus: (status) => debugPrint('Speech status: $status'),
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _startListening() {
    if (!_speechEnabled || _isListening) return;

    setState(() {
      _isListening = true;
    });

    _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          final command = result.recognizedWords;
          debugPrint("Perintah Diterima: $command");
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
          _processVoiceCommand(command);
        }
      },
      listenFor: const Duration(seconds: 10),
      localeId: 'id_ID',
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() {
    if (!_isListening) return;
    
    _speechToText.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _processVoiceCommand(String command) {
    final String cmd = command.toLowerCase();

    String? relayKey;
    String? deviceName;
    bool? value;

    if (cmd.contains("pompa air")) {
      relayKey = 'pompa_air';
      deviceName = 'Pompa Air';
    } else if (cmd.contains("lahan 1") || cmd.contains("lahan satu")) {
      relayKey = 'lahan_1';
      deviceName = 'Lahan 1';
    } else if (cmd.contains("lahan 2") || cmd.contains("lahan dua")) {
      relayKey = 'lahan_2';
      deviceName = 'Lahan 2';
    } else if (cmd.contains("lahan 3") || cmd.contains("lahan tiga")) {
      relayKey = 'lahan_3';
      deviceName = 'Lahan 3';
    }

    if (cmd.contains("nyalakan") || cmd.contains("hidupkan") || cmd.contains("buka") || cmd.contains("on")) {
      value = true;
    } else if (cmd.contains("matikan") || cmd.contains("stop") || cmd.contains("tutup") || cmd.contains("off")) {
      value = false;
    }

    if (relayKey != null && deviceName != null && value != null) {
      _updateRelayStatus(relayKey, deviceName, value);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perintah diterima: $deviceName ${value ? "ON" : "OFF"}'),
            backgroundColor: Theme.of(context).primaryColor,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Perintah suara tidak dikenali: "$command"'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
  // --- AKHIR BLOK FUNGSI SUARA ---


  // --- BLOK FUNGSI RELAY (Tetap sama) ---
  String getUserName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) { return user.displayName!; }
    return user?.email?.split('@')[0] ?? "Pengguna";
  }

  Future<void> _updateRelayStatus(String relayKey, String deviceName, bool value) async {
    final userID = FirebaseAuth.instance.currentUser?.uid;
    if (userID == null) return;

    try {
      await _dbRef.child('kontrol_relay/$relayKey').set(value);

      final userGroupSnapshot = await _dbRef.child('users/$userID/groupID').get();
      String groupName = "Tanpa Kelompok";
      if(userGroupSnapshot.exists) {
        final groupID = userGroupSnapshot.value as String;
        final groupNameSnapshot = await _dbRef.child('groups/$groupID/groupName').get();
        if(groupNameSnapshot.exists) {
          groupName = groupNameSnapshot.value as String;
        }
      }

      final now = DateTime.now();
      final String dateKey = DateFormat('yyyy-MM-dd').format(now);
      final String time = DateFormat('HH:mm').format(now);
      final String userName = getUserName();

      final Map<String, dynamic> logData = {
        'nama': deviceName,
        'aksi': value ? 'ON' : 'OFF',
        'waktu': time,
        'pengguna': userName,
        'kelompok': groupName,
      };
      
      await _dbRef.child('riwayat_penyiraman/$dateKey').push().set(logData);

    } catch (error) {
      if(mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $error'))); }
    }
  }
  // --- AKHIR BLOK FUNGSI RELAY ---


  @override
  Widget build(BuildContext context) {
    return Container( // 1. TAMBAHKAN Container sebagai pembungkus utama
      decoration: const BoxDecoration(gradient: kBackgroundGradient), // 2. PINDAHKAN gradient ke sini
      child: Scaffold(
        // 3. Pastikan Scaffold transparan (sudah di-set di theme, tapi ini lebih aman)
        backgroundColor: Colors.transparent, 
        
        body: IndexedStack( // 4. HAPUS Container pembungkus gradient dari body
          index: _selectedIndex,
          children: _pages,
        ),

      floatingActionButton: FloatingActionButton(
        onPressed: _speechEnabled
            ? (_isListening ? _stopListening : _startListening)
            : null,
        child: Icon(_isListening ? Icons.mic_off : Icons.mic, size: 28),
        backgroundColor: _isListening ? Colors.redAccent : Theme.of(context).primaryColor,
        elevation: 4.0,
        shape: CircleBorder(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(),
    ));
  }
  
  // --- (Sisa kode _buildBottomAppBar, _buildNavItem, HomePage, dll... tetap sama) ---
  // ... (Sisa kode Anda dari _buildBottomAppBar() sampai akhir file) ...

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      height: 65,
      color: Theme.of(context).primaryColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 16),
              _buildNavItem(Icons.home_filled, 0),
              const SizedBox(width: 24),
              _buildNavItem(Icons.bar_chart, 1),
              const SizedBox(width: 16),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 16),
              _buildNavItem(Icons.analytics_outlined, 2),
              const SizedBox(width: 24),
              _buildNavItem(Icons.settings, 3),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final bool isSelected = (_selectedIndex == index);
    return IconButton(
      icon: Icon(
        icon, 
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.7), 
        size: isSelected ? 30 : 28
      ),
      onPressed: () => _onItemTapped(index),
    );
  }
}


class HomePage extends StatefulWidget {
  final Function(String, String, bool) onUpdateRelay;
  
  const HomePage({Key? key, required this.onUpdateRelay}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _pompaOn = false;
  bool _lahan1On = false;
  bool _lahan2On = false;
  bool _lahan3On = false;
  late DateTime _currentTime;
  Timer? _timer;

  String _locationName = "Memuat...";
  String _temperature = "--";
  bool _isFetchingWeather = true;
  final String _apiKey = "e879072c3e610a7d3a93a9ca90e0e011"; 

  late StreamSubscription<DatabaseEvent> _pompaSubscription;
  late StreamSubscription<DatabaseEvent> _lahan1Subscription;
  late StreamSubscription<DatabaseEvent> _lahan2Subscription;
  late StreamSubscription<DatabaseEvent> _lahan3Subscription;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (mounted) { setState(() { _currentTime = DateTime.now(); }); }
    });

    _listenToRelayStatus();
    _determinePositionAndWeather();
  }
  
  Future<void> _determinePositionAndWeather() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      try {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _getWeather(position.latitude, position.longitude);
      } catch (e) {
        if (mounted) { setState(() { _locationName = "Gagal Mendapat Lokasi"; _isFetchingWeather = false; }); }
      }
    } else {
      if (mounted) { setState(() { _locationName = "Izin Lokasi Ditolak"; _isFetchingWeather = false; }); }
    }
  }

  Future<void> _getWeather(double lat, double lon) async {
    final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) { setState(() { _locationName = data['name']; _temperature = data['main']['temp'].round().toString(); _isFetchingWeather = false; }); }
      } else { throw Exception('Gagal memuat data cuaca'); }
    } catch (e) {
      if (mounted) { setState(() { _locationName = "Error Cuaca"; _isFetchingWeather = false; }); }
    }
  }

  void _listenToRelayStatus() {
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    _pompaSubscription = dbRef.child('kontrol_relay/pompa_air').onValue.listen((event) {
      final bool status = (event.snapshot.value ?? false) as bool;
      if (mounted) { setState(() { _pompaOn = status; }); }
    });
    _lahan1Subscription = dbRef.child('kontrol_relay/lahan_1').onValue.listen((event) {
      final bool status = (event.snapshot.value ?? false) as bool;
      if (mounted) { setState(() { _lahan1On = status; }); }
    });
    _lahan2Subscription = dbRef.child('kontrol_relay/lahan_2').onValue.listen((event) {
      final bool status = (event.snapshot.value ?? false) as bool;
      if (mounted) { setState(() { _lahan2On = status; }); }
    });
    _lahan3Subscription = dbRef.child('kontrol_relay/lahan_3').onValue.listen((event) {
      final bool status = (event.snapshot.value ?? false) as bool;
      if (mounted) { setState(() { _lahan3On = status; }); }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pompaSubscription.cancel();
    _lahan1Subscription.cancel();
    _lahan2Subscription.cancel();
    _lahan3Subscription.cancel();
    super.dispose();
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) { return 'Selamat Pagi'; }
    if (hour < 15) { return 'Selamat Siang'; }
    if (hour < 18) { return 'Selamat Sore'; }
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeaderSection(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTemperatureCard(),
                const SizedBox(height: 30),
                _buildSectionTitle("Kontrol Utama"),
                Padding(
                  padding: const EdgeInsets.only(top: 15.0),
                  child: _buildControlGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildHeaderSection() {
  return Container(
    height: 250,
    child: Stack(
      children: [
        Positioned.fill(
            child: ClipRRect(
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40)),
                child: Image.asset('assets/images/header_background.jpg',
                    fit: BoxFit.cover))),
        Positioned.fill(
            child: Container(
                decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40)),
                    gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter)))),
        Positioned(
          top: 60,
          left: 24,
          right: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row( 
                crossAxisAlignment: CrossAxisAlignment.center, 
                children: [
                  Container(
                    padding: const EdgeInsets.all(5), 
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(1),
                      borderRadius: BorderRadius.circular(10), 
                    ),
                    child: Image.asset(
                      'assets/images/icon.png', 
                      width: 35, 
                      height: 35,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 10), 
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(getGreeting(),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16)),
                      Text(FirebaseAuth.instance.currentUser?.displayName ?? "Pengguna",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: Text("Rawat Lahan, Ciptakan Kehidupan",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10.0, color: Colors.black45)]))),
      ],
    ),
  );
}

  Widget _buildTemperatureCard() {
    final String formattedDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_currentTime);
    final String formattedTime = DateFormat('HH:mm').format(_currentTime);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.grey),
                  const SizedBox(width: 5),
                  Text(_locationName, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  Text(formattedTime, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.thermostat_outlined, size: 45, color: Colors.redAccent),
              const SizedBox(width: 15),
              _isFetchingWeather
                  ? const CircularProgressIndicator()
                  : Text("$_temperature°C", style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w600, color: Color(0xFF333333))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }

  Widget _buildControlGrid() {
    return GridView.count(
      crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildControlCard(icon: Icons.water, deviceName: "Pompa Air", isActive: _pompaOn, onToggle: (value) { widget.onUpdateRelay('pompa_air', 'Pompa Air', value); }),
        _buildControlCard(icon: Icons.looks_one_outlined, deviceName: "Lahan 1", isActive: _lahan1On, onToggle: (value) { widget.onUpdateRelay('lahan_1', 'Lahan 1', value); }),
        _buildControlCard(icon: Icons.looks_two_outlined, deviceName: "Lahan 2", isActive: _lahan2On, onToggle: (value) { widget.onUpdateRelay('lahan_2', 'Lahan 2', value); }),
        _buildControlCard(icon: Icons.looks_3_outlined, deviceName: "Lahan 3", isActive: _lahan3On, onToggle: (value) { widget.onUpdateRelay('lahan_3', 'Lahan 3', value); }),
      ],
    );
  }

  Widget _buildControlCard({required IconData icon, required String deviceName, required bool isActive, required Function(bool) onToggle}) {
    final Color textColor = isActive ? Colors.white : const Color(0xFF333333);
    final Color iconColor = isActive ? Colors.white : Theme.of(context).primaryColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isActive ? kActiveGradient : null,
        color: isActive ? null : kCardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 35, color: iconColor),
          const Spacer(),
          Text(isActive ? "ON" : "OFF", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(deviceName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 5),
          Switch(value: isActive, onChanged: onToggle, activeColor: Colors.white, activeTrackColor: Colors.white.withAlpha(128), inactiveThumbColor: Colors.grey[400], inactiveTrackColor: Colors.grey[200]),
        ],
      ),
    );
  }
}