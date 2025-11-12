// lib/sensor_data_page.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Import untuk konstanta
import 'package:intl/intl.dart';

// Model Baru untuk menyimpan info kegiatan
class ActivityItem {
  final String name;
  final String category; // 'Individu', 'Kelompok', 'Mingguan'
  bool isCompleted;
  bool isOnCooldown;
  bool isEnabled; // Apakah checkbox bisa diubah oleh user saat ini

  ActivityItem({
    required this.name,
    required this.category,
    this.isCompleted = false,
    this.isOnCooldown = false,
    this.isEnabled = false,
  });
}


class SensorDataPage extends StatefulWidget {
  const SensorDataPage({Key? key}) : super(key: key);

  @override
  _SensorDataPageState createState() => _SensorDataPageState();
}

class _SensorDataPageState extends State<SensorDataPage>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  
  // State untuk data sensor
  Map<String, String> _sensorData = {};
  bool _isLoadingSensors = true;
  String _errorMessage = '';

  // State untuk data kegiatan
  List<ActivityItem> _activities = []; 
  bool _isLoadingActivities = true;
  bool _userHasGroup = false;
  String? _userGroupId; 
  Set<String> _completedIndividually = {};
  Set<String> _completedByGroup = {};
  List<String> _masterActivities = [];
  Map<String, DateTime> _lastCompletedMap = {};

  // --- PERBAIKAN: Latch menyimpan DateTime ---
  // Menyimpan data mentah dari global_activity_latch
  Map<String, Map<String, dynamic>> _fullGlobalLatch = {};
  // Menyimpan HANYA tanggal latch untuk GRUP PENGGUNA SAAT INI
  Map<String, DateTime> _groupLatchDateMap = {}; 
  StreamSubscription<DatabaseEvent>? _globalLatchSubscription;

  // Referensi Firebase
  final DatabaseReference _sensorRef = FirebaseDatabase.instance.ref('data_sensor');
  final DatabaseReference _activityRef = FirebaseDatabase.instance.ref();
  StreamSubscription<DatabaseEvent>? _sensorSubscription;
  StreamSubscription<DatabaseEvent>? _individualActivitySubscription;
  StreamSubscription<DatabaseEvent>? _groupActivitySubscription;
  StreamSubscription<DatabaseEvent>? _weeklyStatusSubscription;


  // Controller
  final ScrollController _scrollController = ScrollController();
  TabController? _tabController;

  // --- PERBAIKAN: Mendefinisikan semua kategori di sini ---
final Set<String> _individualActivitiesSet = {
    "Pemberian pupuk organik dan kompos",
    "Pembersihan gulma dan pengendalian hama alami",
  };
  final Set<String> _groupActivitiesSet = {
    "Penyiraman rutin (dibagi per kelompok)",
    "Pembuatan laporan perkembangan tanaman tiap kelompok",
  };
  final Set<String> _weeklyActivitiesSet = {
    "Monitoring pertumbuhan tanaman (mingguan)",
  };


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDataForDate(_selectedDate); // Fetch data sensor
    _fetchInitialActivities(_selectedDate); // Fetch data kegiatan awal
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  // 1. Mengambil data awal (hanya data snapshot)
  Future<void> _fetchInitialActivities(DateTime date) async {
    final userID = FirebaseAuth.instance.currentUser?.uid;
    if (userID == null) return;

    setState(() { _isLoadingActivities = true; });

    try {
      final userGroupSnapshot = await _activityRef.child('users/$userID/groupID').get();
      _userGroupId = userGroupSnapshot.exists ? userGroupSnapshot.value as String : null;
      _userHasGroup = _userGroupId != null;

      final dateKey = DateFormat('yyyy-MM-dd').format(date);

      List<Future<DataSnapshot>> fetches = [
        _activityRef.child('daftar_kegiatan').get(),
        _activityRef.child('kegiatan_selesai_individu/$userID/$dateKey').get(),
        // --- PERBAIKAN: Ambil Latch global, BUKAN cooldown harian ---
        _activityRef.child('global_activity_latch').get(), 
      ];

      if (_userHasGroup) {
        fetches.add(_activityRef.child('status_kegiatan_mingguan/$_userGroupId').get());
        fetches.add(_activityRef.child('kegiatan_selesai_kelompok/$_userGroupId/$dateKey').get());
      }

      final snapshots = await Future.wait(fetches);

      // Proses daftar_kegiatan (snapshots[0]) - tidak berubah
      _masterActivities = [];
      final masterListSnapshot = snapshots[0];
      if (masterListSnapshot.exists && masterListSnapshot.value != null) {
          final Map<dynamic, dynamic> categoriesData = masterListSnapshot.value as Map<dynamic, dynamic>;
          categoriesData.forEach((category, activities) {
            if (activities is List) {
              _masterActivities.addAll(List<String>.from(activities));
            }
          });
      }

      // Proses ceklis individu (snapshots[1]) - tidak berubah
      _completedIndividually.clear();
      final individualSnapshot = snapshots[1];
      if (individualSnapshot.exists && individualSnapshot.value != null) {
        final data = individualSnapshot.value as Map<dynamic, dynamic>;
        _completedIndividually.addAll(data.keys.cast<String>());
      }
      
      // --- PERBAIKAN: Proses data Latch Global ---
      // --- PERBAIKAN: Proses data Latch Global (dengan DateTime) ---
      _fullGlobalLatch.clear();
      _groupLatchDateMap.clear();
      final globalLatchSnapshot = snapshots[2]; // Ambil dari indeks 2
      if (globalLatchSnapshot.exists && globalLatchSnapshot.value != null) {
        final data = globalLatchSnapshot.value as Map<dynamic, dynamic>;
        data.forEach((activityName, groupMap) {
          if (groupMap is Map) {
            final castedGroupMap = groupMap.cast<String, dynamic>();
            _fullGlobalLatch[activityName] = castedGroupMap;
            
            // Cek apakah grup pengguna ada di latch ini
            if (_userGroupId != null && castedGroupMap.containsKey(_userGroupId)) {
              try {
                // Simpan tanggal latch untuk grup ini
                _groupLatchDateMap[activityName] = DateTime.parse(castedGroupMap[_userGroupId] as String);
              } catch (e) {
                print("Gagal parse tanggal latch: $e");
              }
            }
          }
        });
      }
      
      _lastCompletedMap.clear();
      _completedByGroup.clear();
      if (_userHasGroup) {
        final weeklyStatusSnapshot = snapshots[3]; // Ganti jadi 3
        if (weeklyStatusSnapshot.exists && weeklyStatusSnapshot.value != null) {
          final data = weeklyStatusSnapshot.value as Map<dynamic, dynamic>;
          data.forEach((key, value) { try { _lastCompletedMap[key] = DateTime.parse(value); } catch (e) {} });
        }
        
        final groupSnapshot = snapshots[4]; // Ganti jadi 4
        if (groupSnapshot.exists && groupSnapshot.value != null) {
            final data = groupSnapshot.value as Map<dynamic, dynamic>;
            _completedByGroup.addAll(data.keys.cast<String>());
        }
      }

      _rebuildActivityList(); 
      _attachRealtimeListeners(date); 
      
      if(mounted) {
        setState(() { _isLoadingActivities = false; });
      }

    } catch (e) {
      print("Error fetching initial activities: $e");
      if (mounted) { setState(() { _isLoadingActivities = false; }); }
    }
  }
  
  // 2. Memasang listener untuk update real-time
  void _attachRealtimeListeners(DateTime date) {
    final userID = FirebaseAuth.instance.currentUser?.uid;
    if (userID == null) return;
    
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    
    _individualActivitySubscription?.cancel();
    _groupActivitySubscription?.cancel();
    _weeklyStatusSubscription?.cancel();
    _globalLatchSubscription?.cancel();
    _globalLatchSubscription?.cancel(); // Cancel nama baru

    // Listener Individu (Tidak berubah)
    _individualActivitySubscription = _activityRef.child('kegiatan_selesai_individu/$userID/$dateKey').onValue.listen((event) {
      _completedIndividually.clear(); 
      if (event.snapshot.exists && event.snapshot.value != null) {
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          _completedIndividually.addAll(data.keys.cast<String>());
      }
      _rebuildActivityList();
    });

    // Listener Kelompok & Mingguan (Tidak berubah)
    if (_userGroupId != null) {
      _groupActivitySubscription = _activityRef.child('kegiatan_selesai_kelompok/$_userGroupId/$dateKey').onValue.listen((event) {
        _completedByGroup.clear(); 
        if (event.snapshot.exists && event.snapshot.value != null) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            _completedByGroup.addAll(data.keys.cast<String>());
        }
        _rebuildActivityList();
      });
      _weeklyStatusSubscription = _activityRef.child('status_kegiatan_mingguan/$_userGroupId').onValue.listen((event) {
          _lastCompletedMap.clear();
          if (event.snapshot.exists && event.snapshot.value != null) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            data.forEach((key, value) { 
              try { _lastCompletedMap[key] = DateTime.parse(value); } catch (e) {} 
            });
          }
          _rebuildActivityList(); 
      });
    }

    // --- PERBAIKAN: Listener untuk Latch Global (dengan DateTime) ---
    _globalLatchSubscription = _activityRef.child('global_activity_latch').onValue.listen((event) {
      _fullGlobalLatch.clear();
      _groupLatchDateMap.clear();
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        data.forEach((activityName, groupMap) {
          if (groupMap is Map) {
            final castedGroupMap = groupMap.cast<String, dynamic>();
            _fullGlobalLatch[activityName] = castedGroupMap;

            if (_userGroupId != null && castedGroupMap.containsKey(_userGroupId)) {
              try {
                _groupLatchDateMap[activityName] = DateTime.parse(castedGroupMap[_userGroupId] as String);
              } catch (e) {
                 print("Gagal parse tanggal latch (listener): $e");
              }
            }
          }
        });
      }
      _rebuildActivityList(); // Rebuild UI jika latch berubah
    });
  }

  // --- PERBAIKAN: Menggunakan Set Kategori lokal ---
  String _getCategoryForActivity(String activityName) {
    final String cleanName = activityName.trim();
    // Gunakan cleanName untuk perbandingan
    if (_individualActivitiesSet.contains(cleanName)) return 'Individu';
    if (_groupActivitiesSet.contains(cleanName)) return 'Kelompok';
    if (_weeklyActivitiesSet.contains(cleanName)) return 'Mingguan';
    // Fallback jika database tidak sinkron dengan Set
    return 'Individu'; 
  }

  // 3. Fungsi untuk membangun UI
  // --- GANTI SELURUH FUNGSI INI ---
  void _rebuildActivityList() {
      if (!mounted) return;
      final now = DateTime.now();
      final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
      List<ActivityItem> currentActivities = [];

      for (var activityName in _masterActivities) {
          final category = _getCategoryForActivity(activityName);
          bool isCompletedForDay = false; // Status ceklis harian (untuk lihat history)
          bool isOnCooldown = false; // Untuk Mingguan
          bool isLatched = false; // Untuk Kelompok
          
          // 1. Tentukan status 'isCompleted' Harian (history)
          if (category == 'Individu') {
            isCompletedForDay = _completedIndividually.contains(activityName);
          } else { 
            isCompletedForDay = _completedByGroup.contains(activityName);
          }

          // 2. Tentukan status Cooldown/Latch (State)
          if (category == 'Kelompok') {
            final lastLatched = _groupLatchDateMap[activityName];
            if (lastLatched != null) { 
              isLatched = true; 
            }
          } 
          else if (category == 'Mingguan') {
            final lastCompleted = _lastCompletedMap[activityName];
            if (lastCompleted != null) {
              if (DateTime.now().difference(lastCompleted).inDays < 7) { 
                isOnCooldown = true; 
              }
            }
          }

          // 3. Tentukan nilai akhir checkbox (centang)
          bool finalCheckboxValue = false;
          if (category == 'Individu') {
            finalCheckboxValue = isCompletedForDay;
          }
          else if (category == 'Kelompok') {
            if (isToday) { finalCheckboxValue = isCompletedForDay || isLatched; } 
            else { finalCheckboxValue = isCompletedForDay; }
          }
          else if (category == 'Mingguan') {
            if (isToday) { finalCheckboxValue = isCompletedForDay || isOnCooldown; } 
            else { finalCheckboxValue = isCompletedForDay; }
          }

          // 4. Tentukan status 'isEnabled' (BERDASARKAN finalCheckboxValue)
          bool isEnabled = false;
          if (finalCheckboxValue) {
            // JIKA SUDAH SELESAI (finalCheckboxValue == true), SELALU nonaktifkan
            isEnabled = false; 
          } else if (!isToday) {
            // JIKA BUKAN HARI INI, nonaktifkan
            isEnabled = false;
          } else {
            // HARI INI dan BELUM SELESAI
            if (category == 'Individu') {
              isEnabled = true;
            } else {
              // Kelompok & Mingguan butuh grup
              isEnabled = _userHasGroup;
            }
          }

          // 5. Buat item
          currentActivities.add(ActivityItem(
            name: activityName, category: category,
            isCompleted: finalCheckboxValue, 
            isOnCooldown: isOnCooldown,
            isEnabled: isEnabled, // Gunakan isEnabled baru
          ));
      }
      
      currentActivities.sort((a, b) {
        int categoryOrder(String cat) {
          if (cat == 'Individu') return 0; if (cat == 'Kelompok') return 1; if (cat == 'Mingguan') return 2; return 3;
        }
        return categoryOrder(a.category).compareTo(categoryOrder(b.category));
      });

      setState(() {
          _activities = currentActivities;
      });
  }

  // --- GANTI FUNGSI INI ---
  // Logika 'else' (uncheck) telah dihapus
  Future<void> _updateActivityStatus(String activityName, bool isCompleted) async {
    // Jika user mencoba 'uncheck' (isCompleted == false), 
    // fungsi ini tidak akan melakukan apa-apa.
    if (!isCompleted) {
      return; 
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userID = user.uid;
    final userName = user.displayName ?? user.email?.split('@')[0] ?? 'Anonim';
    
    final category = _getCategoryForActivity(activityName);
    String dataOwnerId = userID;
    String basePath = 'kegiatan_selesai_individu';

    if (category == 'Kelompok' || category == 'Mingguan') {
      if (_userGroupId == null) return; 
      dataOwnerId = _userGroupId!;
      basePath = 'kegiatan_selesai_kelompok';
    }
    
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final activityPath = '$basePath/$dataOwnerId/$todayKey/$activityName';

    // Logika 'if (isCompleted)' tetap ada
    // 1. Tulis data harian (untuk history)
    final Map<String, String> completionData = { 'completedBy': userID, 'userName': userName };
    await _activityRef.child(activityPath).set(completionData);

    // 2. Tulis data cooldown mingguan (jika mingguan) - TIDAK BERUBAH
    if (category == 'Mingguan' && _userGroupId != null) { 
      await _activityRef.child('status_kegiatan_mingguan/$_userGroupId/$activityName').set(today.toIso8601String());
    }
    
    // 3. Tulis data Latch Global (jika kelompok) - TIDAK BERUBAH
    if (category == 'Kelompok' && _userGroupId != null) {
       await _activityRef.child('global_activity_latch/$activityName/$_userGroupId').set(today.toIso8601String());

       // Update state lokal untuk pengecekan
       _fullGlobalLatch[activityName] = _fullGlobalLatch[activityName] ?? {};
       _fullGlobalLatch[activityName]![_userGroupId!] = today.toIso8601String();
       
      // Cek apakah ini grup terakhir, jika ya, reset latch
      await _checkAndResetGlobalLatch(activityName);
    }
    
    // Blok 'else' (untuk uncheck) telah dihapus seluruhnya.
  }

  void _scrollToSelectedDate() {
    const double itemWidth = 68.0;
    final screenWidth = MediaQuery.of(context).size.width;
    double offset = (_selectedDate.day - 1) * itemWidth - (screenWidth / 2) + (itemWidth / 2);
    if (offset < 0) offset = 0;
     if (_scrollController.hasClients) {
       _scrollController.animateTo(offset, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
     }
  }

  Future<void> _fetchDataForDate(DateTime date) async {
    _sensorSubscription?.cancel();
    setState(() { _isLoadingSensors = true; _errorMessage = ''; });
    final String dateKey = DateFormat('yyyy-MM-dd').format(date);
    _sensorSubscription = _sensorRef.child(dateKey).onValue.listen((event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;
        if (mounted) {
          setState(() {
            if (data != null) {
              _sensorData = Map<String, String>.from(data.map((key, value) => MapEntry(key.toString(), value.toString())));
              _errorMessage = '';
            } else {
              _sensorData = {};
              _errorMessage = 'Tidak ada data sensor tercatat untuk ${DateFormat('dd MMMM yyyy', 'id_ID').format(date)}.';
            }
            _isLoadingSensors = false;
          });
        }
      }, onError: (error) {
        if (mounted) {
          setState(() { _errorMessage = 'Gagal memuat data.'; _isLoadingSensors = false; });
        }
      });
  }

  void _handleDateChange(DateTime newDate) {
    setState(() { _selectedDate = newDate; });
    _fetchDataForDate(newDate);
    _fetchInitialActivities(newDate); 
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelectedDate());
  }

  void _goToPreviousDay() { _handleDateChange(_selectedDate.subtract(const Duration(days: 1))); }
  void _goToNextDay() { _handleDateChange(_selectedDate.add(const Duration(days: 1))); }

  Future<void> _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030), initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && picked != _selectedDate) {
      _handleDateChange(picked);
    }
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    _individualActivitySubscription?.cancel();
    _groupActivitySubscription?.cancel();
    _weeklyStatusSubscription?.cancel();
    _globalLatchSubscription?.cancel();
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: kBackgroundGradient),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildCalendar(),
                const SizedBox(height: 20),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildActivityContent(),
                      _buildSensorContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TAMBAHKAN FUNGSI BARU UNTUK KONFIRMASI ---
  Future<void> _showConfirmationDialog(String activityName) async {
    // Pastikan hanya dipanggil jika konteks masih valid
    if (!mounted) return;

    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Konfirmasi Tugas"),
          content: Text("Apakah Anda yakin ingin menyelesaikan tugas ini?\n\n($activityName)\n\nTugas yang sudah selesai tidak dapat dibatalkan."),
          actions: <Widget>[
            TextButton(
              child: const Text("Batal"),
              onPressed: () {
                Navigator.of(dialogContext).pop(false); // Kirim 'false'
              },
            ),
            TextButton(
              child: const Text("Konfirmasi"),
              onPressed: () {
                Navigator.of(dialogContext).pop(true); // Kirim 'true'
              },
            ),
          ],
        );
      },
    );

    // Hanya panggil update jika user menekan "Konfirmasi" (isConfirmed == true)
    if (isConfirmed == true) {
      // Panggil fungsi update, selalu dengan 'true'
      await _updateActivityStatus(activityName, true);
    }
  }

  // --- TAMBAHKAN FUNGSI BARU INI ---
  // --- FUNGSI LAMA _checkAndSetGlobalCooldown DIGANTI DENGAN INI ---
  Future<void> _checkAndResetGlobalLatch(String activityName) async {
    try {
      // 1. Ambil daftar semua grup yang ada
      final allGroupsSnapshot = await _activityRef.child('groups').get();
      if (!allGroupsSnapshot.exists) return;
      final allGroupsMap = allGroupsSnapshot.value as Map<dynamic, dynamic>;
      final allGroupIds = allGroupsMap.keys.toSet();

      // 2. Ambil daftar grup yang sudah "latch" dari data mentah
      final Map<String, dynamic> latchedGroupMap = _fullGlobalLatch[activityName] ?? {};
      final Set<String> latchedGroupIds = latchedGroupMap.keys.toSet();

      // 3. Cek apakah semua grup sudah latch
      //    Cek apakah set ID grup di DB sama dengan set ID grup yang sudah latch
      if (allGroupIds.every((id) => latchedGroupIds.contains(id)) && latchedGroupIds.every((id) => allGroupIds.contains(id))) {
        // Jika YA: Reset latch untuk kegiatan ini
        await _activityRef.child('global_activity_latch/$activityName').remove();
      }
    } catch (e) {
      print("Error saat cek/reset global latch: $e");
    }
  }

// Salin dan ganti seluruh fungsi _buildTabBar Anda

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: TabBar(
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color.fromARGB(185, 30, 194, 58),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        tabs: const [
          // --- PERUBAHAN DI SINI ---
          Tab(text: "   Kegiatan Harian   "), // Pindahkan ke posisi pertama (kiri)
          Tab(text: "   Laporan Sensor    "),   // Pindahkan ke posisi kedua (kanan)
        ],
      ),
    );
  }

  Widget _buildSensorContent() {
    Widget content;
    if (_isLoadingSensors) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height / 4),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text("Memuat data sensor..."),
          ],
        ),
      );
    } else if (_errorMessage.isNotEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height / 4),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(_errorMessage, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    } else {
      content = _buildSensorDataCards(); // Konten asli Anda
    }

    // Bungkus semuanya dengan RefreshIndicator dan SingleChildScrollView
    return RefreshIndicator(
      onRefresh: () => _fetchDataForDate(_selectedDate),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        // Ini PENTING: agar refresh bisa jalan walau konten kosong
        physics: const AlwaysScrollableScrollPhysics(),
        child: content,
      ),
    );
  }

  Widget _buildActivityContent() {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
    
    final individualActivities = _activities.where((a) => _getCategoryForActivity(a.name) == 'Individu').toList();
    final groupActivities = _activities.where((a) => _getCategoryForActivity(a.name) == 'Kelompok').toList();
    final weeklyActivities = _activities.where((a) => _getCategoryForActivity(a.name) == 'Mingguan').toList();

    // Ini adalah widget konten utama (tugas, loading, atau 'empty')
    Widget content;
    if (_isLoadingActivities) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height / 4), // Beri jarak
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text("Memuat data kegiatan..."),
          ],
        ),
      );
    } else if (_masterActivities.isEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: MediaQuery.of(context).size.height / 4), // Beri jarak
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text("Daftar kegiatan belum diatur di database.", textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    } else {
      // Ini adalah konten asli Anda jika data ada
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_userHasGroup && (_activities.any((a) => _getCategoryForActivity(a.name) != 'Individu')))
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Text("Bergabunglah dengan kelompok untuk mengerjakan tugas Kelompok & Mingguan.", style: TextStyle(color: Colors.orange.shade800)),
            ),

          if (individualActivities.isNotEmpty) ...[
            const Text("Kegiatan Individu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildActivityListContainer(individualActivities, isToday),
            const SizedBox(height: 20),
          ],

          if (groupActivities.isNotEmpty) ...[
            const Text("Kegiatan Kelompok", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildActivityListContainer(groupActivities, isToday),
            const SizedBox(height: 20),
          ],
          
          if (weeklyActivities.isNotEmpty) ...[
            const Text("Kegiatan Mingguan", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildActivityListContainer(weeklyActivities, isToday),
            const SizedBox(height: 20),
          ],
        ],
      );
    }

    // Bungkus semuanya dengan RefreshIndicator dan SingleChildScrollView
    return RefreshIndicator(
      onRefresh: () => _fetchInitialActivities(_selectedDate),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        // Ini PENTING: agar refresh bisa jalan walau konten kosong (saat loading)
        physics: const AlwaysScrollableScrollPhysics(), 
        child: content,
      ),
    );
  }
  // --- GANTI SELURUH WIDGET INI ---
  Widget _buildActivityListContainer(List<ActivityItem> activities, bool isToday) {
     return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
          
          // 'canChange' sekarang HANYA 'activity.isEnabled'
          final bool canChange = activity.isEnabled; 
          final bool shouldStrikeThrough = activity.isOnCooldown && !activity.isCompleted && !isToday;

          return CheckboxListTile(
            title: Text(
              activity.name, 
              style: TextStyle(
                // Warna abu-abu jika 'canChange' false DAN 'isCompleted' false
                color: !canChange && !activity.isCompleted ? Colors.grey : Colors.black,
                decoration: shouldStrikeThrough ? TextDecoration.lineThrough : TextDecoration.none,
              )
            ),
            value: activity.isCompleted,
            
            // --- PERUBAHAN LOGIKA ONCHANGED ---
            onChanged: canChange 
              ? (bool? value) {
                  // Karena 'canChange' akan false jika sudah completed,
                  // 'value' di sini PASTI true (transisi dari false->true)
                  if (value == true) { 
                    _showConfirmationDialog(activity.name);
                  }
                  // Tidak perlu 'else' karena uncheck sudah dicegah
                  // oleh 'canChange' yang bernilai 'null'
                }
              : null, // Jika 'canChange' false, onChanged adalah null (nonaktif)
              
            activeColor: Theme.of(context).primaryColor,
            controlAffinity: ListTileControlAffinity.leading,
            // Beri warna latar abu-abu jika nonaktif DAN belum selesai
            tileColor: !canChange && !activity.isCompleted ? Colors.grey.shade100 : null,
          );
        },
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
      ),
    );
  }

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Text("Report", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCalendar() {
    final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _selectMonth(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _goToPreviousDay),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: _goToNextDay),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 80,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            itemCount: daysInMonth, 
            itemBuilder: (context, index) {
              final day = index + 1;
              final date = DateTime(_selectedDate.year, _selectedDate.month, day);
              final isSelected = day == _selectedDate.day;
              return GestureDetector(
                onTap: () => _handleDateChange(date),
                child: Container(
                  width: 60,
                  margin: EdgeInsets.only(left: index == 0 ? 24 : 8, right: index == daysInMonth - 1 ? 24 : 8),
                  decoration: BoxDecoration(color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.white, borderRadius: BorderRadius.circular(15), border: isSelected ? Border.all(color: Theme.of(context).primaryColor) : null),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateFormat('E', 'id_ID').format(date), style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.grey)),
                      const SizedBox(height: 5),
                      Text(day.toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSensorDataCards() {
    return Column(
      children: [
        _buildDataCard(icon: Icons.thermostat, label: "Suhu Udara", value: _sensorData['suhu_udara'] ?? 'N/A', color: Colors.orangeAccent),
        const SizedBox(height: 15),
        _buildDataCard(icon: Icons.opacity, label: "Humidity", value: _sensorData['humidity'] ?? 'N/A', color: Colors.blueAccent),
        const SizedBox(height: 15),
        _buildDataCard(icon: Icons.grass, label: "Soil Moisture", value: _sensorData['soil_moisture'] ?? 'N/KA', color: Colors.brown),
        const SizedBox(height: 15),
        _buildDataCard(icon: Icons.waves, label: "Water Level", value: _sensorData['water_level'] ?? 'N/A', color: Colors.lightBlue),
      ],
    );
  }

  Widget _buildDataCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        children: [
          CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 28)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 5),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}