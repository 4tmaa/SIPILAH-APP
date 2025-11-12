// lib/analysis_page.dart
// (GANTI SELURUH ISI FILE DENGAN KODE DI BAWAH INI)

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Import untuk konstanta
import 'package:intl/intl.dart';

// --- REVISI: Tambahkan 'activityGroupId' untuk perbandingan ---
class AnalysisLog {
  final String id; // Kunci unik dari Firebase
  final String type; // 'penyiraman' or 'kegiatan'
  final String name; // Nama perangkat atau kegiatan
  final String action; // ON/OFF atau Selesai
  final DateTime? dateTime; // Simpan sebagai DateTime
  final String user; // Nama pengguna yang melakukan
  final String? groupName; // Nama kelompok DARI log (e.g., "PKK RT 01")
  final String? activityGroupId; // ID kelompok DARI log (e.g., "-M123xyz")

  AnalysisLog({
    required this.id,
    required this.type,
    required this.name,
    required this.action,
    required this.dateTime,
    required this.user,
    this.groupName,
    this.activityGroupId,
  });

  DateTime? getDateTime() {
    return dateTime;
  }
}

// Enum untuk filter (Tidak Berubah)
enum FilterDateType { day, week, month, year }
enum FilterMainType { all, penyiraman, kegiatan }
enum FilterPenyiramanType { all, on, off }
enum FilterKegiatanType { all, kelompok, individu, mingguan }

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({Key? key}) : super(key: key);

  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  
  // --- REVISI: Ubah listener grup menjadi list ---
  StreamSubscription<DatabaseEvent>? _penyiramanSubscription;
  StreamSubscription<DatabaseEvent>? _kegiatanSubscriptionUser;
  List<StreamSubscription<DatabaseEvent>> _groupKegiatanSubscriptions = [];

  DateTime _selectedDate = DateTime.now();
  FilterDateType _dateFilter = FilterDateType.day;
  FilterMainType _mainFilter = FilterMainType.all;
  FilterPenyiramanType _penyiramanFilter = FilterPenyiramanType.all;
  FilterKegiatanType _kegiatanFilter = FilterKegiatanType.all;

  // --- REVISI: Pisahkan list untuk tiap listener ---
  List<AnalysisLog> _penyiramanLogs = [];
  List<AnalysisLog> _userKegiatanLogs = [];
  // --- REVISI: Gunakan Map untuk menyimpan log dari semua grup ---
  Map<String, List<AnalysisLog>> _groupKegiatanLogsMap = {};

  List<AnalysisLog> _filteredLogs = [];
  bool _isLoading = true;
  String? _userGroupId; // ID Grup milik PENGGUNA SAAT INI

  // --- REVISI: Map untuk menyimpan semua nama grup (ID -> Nama) ---
  Map<String, String> _allGroupNames = {};

  final Set<String> _weeklyActivitiesSet = {
    "Monitoring pertumbuhan tanaman (mingguan)",
  };

  @override
  void initState() {
    super.initState();
    _fetchUserGroupAndInitialData();
  }

  Future<void> _fetchUserGroupAndInitialData() async {
    final userID = FirebaseAuth.instance.currentUser?.uid;
    if (userID == null) { setState(() => _isLoading = false); return; }

    // 1. Ambil ID grup pengguna saat ini
    final userGroupSnapshot = await _dbRef.child('users/$userID/groupID').get();
    if (userGroupSnapshot.exists) {
      _userGroupId = userGroupSnapshot.value as String;
    }

    // --- REVISI: 2. Ambil SEMUA nama grup ---
    _allGroupNames.clear();
    final groupsSnapshot = await _dbRef.child('groups').get();
    if (groupsSnapshot.exists && groupsSnapshot.value != null) {
      final data = groupsSnapshot.value as Map<dynamic, dynamic>;
      data.forEach((groupId, groupData) {
        if (groupData is Map && groupData.containsKey('groupName')) {
          _allGroupNames[groupId] = groupData['groupName'] as String;
        }
      });
    }
    
    // 3. Ambil data
    _fetchData();
  }

Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    _penyiramanSubscription?.cancel();
    _kegiatanSubscriptionUser?.cancel();
    // --- REVISI: Cancel semua listener grup ---
    _groupKegiatanSubscriptions.forEach((sub) => sub.cancel());
    _groupKegiatanSubscriptions.clear();

    _penyiramanLogs = [];
    _userKegiatanLogs = [];
    _groupKegiatanLogsMap.clear();

    final userID = FirebaseAuth.instance.currentUser?.uid;
    if (userID == null) return;

    // --- Logika rentang tanggal (Tidak Berubah) ---
    String startKey;
    String endKey;

    if (_dateFilter == FilterDateType.day) {
      startKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      endKey = startKey;
    } else if (_dateFilter == FilterDateType.month) {
      startKey = DateFormat('yyyy-MM').format(_selectedDate);
      endKey = startKey;
    } else if (_dateFilter == FilterDateType.year) {
      startKey = DateFormat('yyyy').format(_selectedDate);
      endKey = startKey;
    } else { // FilterDateType.week
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      startKey = DateFormat('yyyy-MM-dd').format(startOfWeek);
      endKey = DateFormat('yyyy-MM-dd').format(endOfWeek);
    }
    // --- AKHIR LOGIKA TANGGAL ---
    
    try {
      // 1. Ambil data penyiraman (realtime) - Tidak Berubah
      _penyiramanSubscription = _dbRef.child('riwayat_penyiraman')
          .orderByKey().startAt(startKey).endAt('$endKey\uf8ff')
          .onValue.listen((event) { 
            _processPenyiramanSnapshot(event.snapshot);
          }, onError: _handleError);

      String basePathKegiatanIndividu = 'kegiatan_selesai_individu';
      String basePathKegiatanKelompok = 'kegiatan_selesai_kelompok';
      
      // --- REVISI: 2. Loop dan buat listener untuk SEMUA grup ---
      for (final groupId in _allGroupNames.keys) {
        final groupName = _allGroupNames[groupId] ?? 'Grup Tidak Dikenal';
        
        final subscription = _dbRef.child('$basePathKegiatanKelompok/$groupId')
            .orderByKey().startAt(startKey).endAt('$endKey\uf8ff')
            .onValue.listen((event) { 
              _processGroupKegiatanSnapshot(
                event.snapshot, 
                groupId: groupId, 
                groupName: groupName
              ); 
            }, onError: _handleError);
            
        _groupKegiatanSubscriptions.add(subscription);
      }
      
      // 3. Ambil data kegiatan individu (realtime)
      _kegiatanSubscriptionUser = _dbRef.child('$basePathKegiatanIndividu/$userID')
          .orderByKey().startAt(startKey).endAt('$endKey\uf8ff')
          .onValue.listen((event) { 
            _processIndividualKegiatanSnapshot(event.snapshot); 
          }, onError: _handleError);

    } catch (error) {
        _handleError(error);
    }
    
    _applyFilters();
  }
  
  // Fungsi _processPenyiramanSnapshot (Tidak Berubah)
  void _processPenyiramanSnapshot(DataSnapshot snapshot) {
    _penyiramanLogs.clear();
    if (snapshot.exists) {
      final dataPerTanggal = snapshot.value as Map<dynamic, dynamic>;
      dataPerTanggal.forEach((dateKey, dateData) {
        final logsOnDate = dateData as Map<dynamic, dynamic>;
        logsOnDate.forEach((logKey, logValue) {
          _addPenyiramanLog(logKey, logValue, dateKey);
        });
      });
    }
    _applyFilters();
  }

  // Fungsi _addPenyiramanLog (REVISI: tambahkan null untuk ID grup)
  void _addPenyiramanLog(String logKey, Map<dynamic, dynamic> logValue, String dateKey) {
      DateTime? parsedDateTime;
      String timeString = logValue['waktu'] ?? '';
      try {
        parsedDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$dateKey $timeString');
      } catch (e) {
        try {
          parsedDateTime = DateFormat('yyyy-MM-dd').parse(dateKey); 
        } catch (_) {}
      }

      _penyiramanLogs.add(AnalysisLog(
        id: logKey, type: 'penyiraman', name: logValue['nama'] ?? 'N/A', action: logValue['aksi'] ?? 'N/A',
        dateTime: parsedDateTime, user: logValue['pengguna'] ?? 'Tidak Dikenal', 
        groupName: logValue['kelompok'], // Ini adalah nama grup PENGGUNA
        activityGroupId: null, // Penyiraman tidak punya ID grup aktivitas
      ));
  }
  
  // --- REVISI: Buat fungsi baru untuk proses log GRUP ---
  void _processGroupKegiatanSnapshot(DataSnapshot snapshot, {required String groupId, required String groupName}) {
    // Inisialisasi/bersihkan list untuk grup spesifik ini
    _groupKegiatanLogsMap[groupId] = [];
    final List<AnalysisLog> targetList = _groupKegiatanLogsMap[groupId]!;

    if (snapshot.exists) {
      final dataPerTanggal = snapshot.value as Map<dynamic, dynamic>;
      dataPerTanggal.forEach((dateKey, dateData) {
        final activitiesOnDate = dateData as Map<dynamic, dynamic>;
        activitiesOnDate.forEach((activityName, value) {
          if (value is Map && value['completedBy'] != null) { 
            DateTime? activityDate;
            try { activityDate = DateFormat('yyyy-MM-dd').parse(dateKey); } catch (_) {}
            
            targetList.add(AnalysisLog(
              id: '$dateKey-$activityName-$groupId',
              type: 'kegiatan', name: activityName, action: 'Selesai',
              dateTime: activityDate,
              user: value['userName'] ?? 'Tidak Dikenal', // Nama pengguna
              groupName: groupName, // Nama grup (e.g., "PKK RT 01")
              activityGroupId: groupId, // ID grup (e.g., "-M123xyz")
            ));
          }
        });
      });
    }
    _applyFilters();
  }

  // --- REVISI: Buat fungsi baru untuk proses log INDIVIDU ---
  void _processIndividualKegiatanSnapshot(DataSnapshot snapshot) {
    _userKegiatanLogs.clear();

    if (snapshot.exists) {
      final dataPerTanggal = snapshot.value as Map<dynamic, dynamic>;
      dataPerTanggal.forEach((dateKey, dateData) {
        final activitiesOnDate = dateData as Map<dynamic, dynamic>;
        activitiesOnDate.forEach((activityName, value) {
          if (value is Map && value['completedBy'] != null) { 
            DateTime? activityDate;
            try { activityDate = DateFormat('yyyy-MM-dd').parse(dateKey); } catch (_) {}
            
            _userKegiatanLogs.add(AnalysisLog(
              id: '$dateKey-$activityName-${FirebaseAuth.instance.currentUser?.uid}',
              type: 'kegiatan', name: activityName, action: 'Selesai',
              dateTime: activityDate,
              user: value['userName'] ?? 'Tidak Dikenal', // Nama pengguna
              groupName: null, // Individu tidak punya nama grup
              activityGroupId: null, // Individu tidak punya ID grup
            ));
          }
        });
      });
    }
    _applyFilters();
  }

  void _handleError(Object error) {
     if (mounted) {
       setState(() => _isLoading = false);
       print("Error fetching data: $error");
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memuat data: $error")));
     }
  }

  // --- REVISI: Gabungkan log dari _penyiramanLogs, _userKegiatanLogs, dan _groupKegiatanLogsMap ---
  void _applyFilters() {
    List<AnalysisLog> logs = [];
    logs.addAll(_penyiramanLogs);
    logs.addAll(_userKegiatanLogs);
    // Tambahkan semua log dari semua grup
    for (final groupLogs in _groupKegiatanLogsMap.values) {
      logs.addAll(groupLogs);
    }

    // --- SISA FUNGSI FILTER INI TIDAK BERUBAH ---
    // Logika filter (all, penyiraman, kegiatan) tetap sama
    if (_mainFilter == FilterMainType.penyiraman) { logs.removeWhere((log) => log.type != 'penyiraman'); }
    else if (_mainFilter == FilterMainType.kegiatan) { logs.removeWhere((log) => log.type != 'kegiatan'); }

    if (_mainFilter == FilterMainType.penyiraman) {
      if (_penyiramanFilter == FilterPenyiramanType.on) { logs.removeWhere((log) => log.action != 'ON'); }
      else if (_penyiramanFilter == FilterPenyiramanType.off) { logs.removeWhere((log) => log.action != 'OFF'); }
    }

    // Logika filter (individu, kelompok, mingguan) tetap sama
    // Logika ini sudah benar karena memfilter berdasarkan 'groupName' dan 'activityName'
    // yang sudah kita atur dengan benar.
    if (_mainFilter == FilterMainType.kegiatan) {
        if (_kegiatanFilter == FilterKegiatanType.kelompok) { 
          logs.removeWhere((log) => log.groupName == null || _weeklyActivitiesSet.contains(log.name.trim())); 
        }
        else if (_kegiatanFilter == FilterKegiatanType.individu) { 
          logs.removeWhere((log) => log.groupName != null); 
        }
        else if (_kegiatanFilter == FilterKegiatanType.mingguan) { 
          logs.removeWhere((log) => !_weeklyActivitiesSet.contains(log.name.trim())); 
        }
    }

    logs.sort((a, b) {
      final dateTimeA = a.getDateTime(); final dateTimeB = b.getDateTime();
      if (dateTimeA == null && dateTimeB == null) return 0;
      if (dateTimeA == null) return 1;
      if (dateTimeB == null) return -1;
      return dateTimeB.compareTo(dateTimeA);
    });

    if (mounted) { setState(() { _filteredLogs = logs; _isLoading = false; }); }
  }

  @override
  void dispose() {
    _penyiramanSubscription?.cancel();
    _kegiatanSubscriptionUser?.cancel();
    // --- REVISI: Cancel semua listener grup ---
    _groupKegiatanSubscriptions.forEach((sub) => sub.cancel());
    super.dispose();
  }

  // --- SISA KODE (Widget Build) ---
  // (Tidak ada perubahan signifikan, KECUALI di _buildHistoryList)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity, decoration: const BoxDecoration(gradient: kBackgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildDateFilterControls(),
              _buildMainFilterControls(),
              _buildSubFilterControls(),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: _isLoading ? const Center(child: CircularProgressIndicator())
                    : _filteredLogs.isEmpty ? const Center(child: Text("Tidak ada riwayat ditemukan."))
                    : _buildHistoryList(), // <- Fokus perubahan ada di sini
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget _buildHeader, _buildDateFilterControls, _getFormattedDateFilter, _showDatePicker,
  // --- _buildMainFilterControls, _buildSubFilterControls, _buildPenyiramanSubFilter, _buildKegiatanSubFilter
  // --- TIDAK ADA PERUBAHAN SAMA SEKALI. ---
  // (Anda bisa salin-tempel widget-widget itu dari kode lama Anda ke sini)
  // ... (Untuk keringkasan, saya akan langsung ke _buildHistoryList) ...

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
      child: Text("Analysis", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDateFilterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_today_outlined, size: 18), label: Text(_getFormattedDateFilter()),
            onPressed: _showDatePicker, style: TextButton.styleFrom(foregroundColor: Theme.of(context).primaryColor),
          ),
          DropdownButton<FilterDateType>(
            value: _dateFilter, underline: Container(),
            items: const [
              DropdownMenuItem(value: FilterDateType.day, child: Text('Harian')),
              DropdownMenuItem(value: FilterDateType.week, child: Text('Mingguan')),
              DropdownMenuItem(value: FilterDateType.month, child: Text('Bulanan')),
              DropdownMenuItem(value: FilterDateType.year, child: Text('Tahunan')),
            ],
            onChanged: (FilterDateType? newValue) {
              if (newValue != null) { setState(() => _dateFilter = newValue); _fetchData(); }
            },
          ),
        ],
      ),
    );
  }

String _getFormattedDateFilter() {
    if (_dateFilter == FilterDateType.day) return DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate);
    if (_dateFilter == FilterDateType.month) return DateFormat('MMMM yyyy', 'id_ID').format(_selectedDate);
    if (_dateFilter == FilterDateType.year) return DateFormat('yyyy').format(_selectedDate);

    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    final String startFormat = 'dd';
    final String endFormat = 'dd MMM yyyy';

    if (startOfWeek.month != endOfWeek.month || startOfWeek.year != endOfWeek.year) {
      final startFormat = 'dd MMM';
        return '${DateFormat(startFormat, 'id_ID').format(startOfWeek)} - ${DateFormat(endFormat, 'id_ID').format(endOfWeek)}';
    }
    
    return '${DateFormat(startFormat, 'id_ID').format(startOfWeek)} - ${DateFormat(endFormat, 'id_ID').format(endOfWeek)}';
  }

  Future<void> _showDatePicker() async {
      DateTime? picked = await showDatePicker(
        context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)), initialDatePickerMode: _dateFilter == FilterDateType.year ? DatePickerMode.year : DatePickerMode.day,
      );
      if (picked != null && picked != _selectedDate) {
        setState(() => _selectedDate = picked);
        _fetchData();
      }
  }

  Widget _buildMainFilterControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SegmentedButton<FilterMainType>(
        segments: const <ButtonSegment<FilterMainType>>[
          ButtonSegment<FilterMainType>(value: FilterMainType.all, label: Text('Semua    '), icon: Icon(Icons.list)),
          ButtonSegment<FilterMainType>(value: FilterMainType.penyiraman, label: Text('Penyiraman    '), icon: Icon(Icons.water_drop_outlined)),
          ButtonSegment<FilterMainType>(value: FilterMainType.kegiatan, label: Text('Kegiatan    '), icon: Icon(Icons.task_alt)),
        ],
        selected: {_mainFilter},
        onSelectionChanged: (Set<FilterMainType> newSelection) {
          setState(() { _mainFilter = newSelection.first; _penyiramanFilter = FilterPenyiramanType.all; _kegiatanFilter = FilterKegiatanType.all; });
          _applyFilters();
        },
        style: SegmentedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 10)),
      ),
    );
  }
  
  Widget _buildSubFilterControls() {
    if (_mainFilter == FilterMainType.penyiraman) { return _buildPenyiramanSubFilter(); }
    else if (_mainFilter == FilterMainType.kegiatan) { return _buildKegiatanSubFilter(); }
    else { return const SizedBox(height: 50); }
  }

  Widget _buildPenyiramanSubFilter() {
      return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
      child: DropdownButton<FilterPenyiramanType>(
        value: _penyiramanFilter, isExpanded: true, underline: Container(height: 1, color: Colors.grey.shade300),
        items: const [
          DropdownMenuItem(value: FilterPenyiramanType.all, child: Text('Filter Aksi Penyiraman: Semua')),
          DropdownMenuItem(value: FilterPenyiramanType.on, child: Text('Filter Aksi Penyiraman: Hanya ON')),
          DropdownMenuItem(value: FilterPenyiramanType.off, child: Text('Filter Aksi Penyiraman: Hanya OFF')),
        ],
        onChanged: (FilterPenyiramanType? newValue) {
          if (newValue != null) { setState(() => _penyiramanFilter = newValue); _applyFilters(); }
        },
      ),
    );
  }

    Widget _buildKegiatanSubFilter() {
      return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
      child: DropdownButton<FilterKegiatanType>(
        value: _kegiatanFilter, isExpanded: true, underline: Container(height: 1, color: Colors.grey.shade300),
        items: const [
          DropdownMenuItem(value: FilterKegiatanType.all, child: Text('Filter Kegiatan: Semua')),
          DropdownMenuItem(value: FilterKegiatanType.kelompok, child: Text('Filter Kegiatan: Kelompok')),
          DropdownMenuItem(value: FilterKegiatanType.individu, child: Text('Filter Kegiatan: Individu')),
          DropdownMenuItem(value: FilterKegiatanType.mingguan, child: Text('Filter Kegiatan: Mingguan')),
        ],
        onChanged: (FilterKegiatanType? newValue) {
          if (newValue != null) { setState(() => _kegiatanFilter = newValue); _applyFilters(); }
        },
      ),
    );
  }

  // --- REVISI UTAMA: Logika Tampilan di _buildHistoryList ---
  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
      itemCount: _filteredLogs.length,
      itemBuilder: (context, index) {
        final log = _filteredLogs[index];
        final isPenyiraman = log.type == 'penyiraman';
        final isActionOn = log.action == 'ON' || log.action == 'Selesai';
        final dateTime = log.getDateTime();

        // --- Logika Baru Untuk Tampilan ---
        // Pengecekan ini menentukan BAGAIMANA data ditampilkan
        final bool isIndividualActivity = (log.type == 'kegiatan' && log.activityGroupId == null);
        final bool isMyGroupActivity = (log.type == 'kegiatan' && log.activityGroupId == _userGroupId);
        // (Semua yang bukan penyiraman, bukan individu, dan bukan grup saya = grup lain)

        return Card(
          margin: const EdgeInsets.only(bottom: 12), elevation: 2, shadowColor: Colors.black.withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActionOn ? Colors.green.shade100 : Colors.red.shade100,
              child: Icon( isPenyiraman ? (isActionOn ? Icons.water_drop_outlined : Icons.power_off_outlined) : Icons.check_circle_outline, color: isActionOn ? Colors.green : Colors.red, size: 20),
            ),
            title: Text(log.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isPenyiraman ? "Aksi: ${log.action}" : log.action),
                Row(
                  children: [
                    
                    // --- Tampilan untuk RIWAYAT PENYIRAMAN (Lengkap) ---
                    if (isPenyiraman) ...[
                      Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Flexible(child: Text(log.user, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)), 
                      if (log.groupName != null) ...[
                        const Text(" - ", style: TextStyle(color: Colors.grey)),
                        Icon(Icons.group_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Flexible(child: Text(log.groupName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)), 
                      ]
                    ]
                    
                    // --- Tampilan untuk KEGIATAN INDIVIDU SAYA (Hanya Nama) ---
                    else if (isIndividualActivity) ...[
                      Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Flexible(child: Text(log.user, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)), 
                      const Text(" (Individu)", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                    ]

                    // --- Tampilan untuk KEGIATAN GRUP SAYA (Lengkap) ---
                    else if (isMyGroupActivity) ...[
                      Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Flexible(child: Text(log.user, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)), 
                      const Text(" - ", style: TextStyle(color: Colors.grey)),
                      Icon(Icons.group_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Flexible(child: Text(log.groupName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)), 
                    ]

                    // --- Tampilan untuk KEGIATAN GRUP LAIN (Anonim) ---
                    else ...[ // Ini mencakup (log.activityGroupId != _userGroupId)
                      Icon(Icons.group_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      // Tampilkan HANYA nama grup mereka, BUKAN nama user
                      Flexible(child: Text(log.groupName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)), 
                    ]

                  ],
                ),
              ],
            ),
            trailing: Text(
              dateTime != null 
                ? (isPenyiraman ? DateFormat('HH:mm').format(dateTime) : DateFormat('dd MMM').format(dateTime)) 
                : '-',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}