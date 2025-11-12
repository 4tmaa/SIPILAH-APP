// lib/group_management_page.dart
// (GANTI SELURUH ISI FILE DENGAN KODE DI BAWAH INI)

import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/main.dart'; // Import untuk kBackgroundGradient

class GroupManagementPage extends StatefulWidget {
  const GroupManagementPage({Key? key}) : super(key: key);

  @override
  _GroupManagementPageState createState() => _GroupManagementPageState();
}

class _GroupManagementPageState extends State<GroupManagementPage> {
  final _joinCodeController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _dbRef = FirebaseDatabase.instance.ref();
  final _userId = FirebaseAuth.instance.currentUser?.uid;

  // --- State Info Grup Sendiri ---
  String? _currentGroupId;
  String? _currentGroupName;
  String? _joinCode;
  bool _isLoading = true;

  // --- State Data Global (Semua User & Grup) ---
  Map<String, dynamic> _allUsers = {}; // Untuk nama anggota grup sendiri
  Map<String, String> _allGroupNames = {}; // (ID -> Nama) Semua grup
  
  // --- REVISI: State untuk Jadwal Piket Global ---
  // (e.g., {"senin": {"grupA_id": true, "grupB_id": true}, ...})
  Map<String, dynamic> _globalSchedule = {};
  final List<String> _daysOfWeek = [
    'senin', 'selasa', 'rabu', 'kamis', 'jumat', 'sabtu', 'minggu'
  ];
  // --- Akhir Revisi ---

  // --- Listener ---
  StreamSubscription? _userGroupSubscription;
  StreamSubscription? _allUsersSubscription;
  StreamSubscription? _allGroupsSubscription;
  StreamSubscription? _scheduleSubscription;


  @override
  void initState() {
    super.initState();
    // 1. Ambil data awal sekali
    _loadInitialData();
    // 2. Pasang listener
    _setupListeners();
  }

  @override
  void dispose() {
    _userGroupSubscription?.cancel();
    _allUsersSubscription?.cancel();
    _allGroupsSubscription?.cancel();
    _scheduleSubscription?.cancel();
    _joinCodeController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }
  
  // --- REVISI: Gabungkan semua pengambilan data awal ---
  Future<void> _loadInitialData() async {
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // 1. Ambil data grup pengguna saat ini (termasuk kode gabung)
      final userSnapshot = await _dbRef.child('users/$_userId/groupID').get();
      if (userSnapshot.exists) {
        final groupId = userSnapshot.value as String;
        _currentGroupId = groupId; // Set state internal
        
        final groupSnapshot = await _dbRef.child('groups/$groupId').get();
        if (groupSnapshot.exists) {
          final groupData = groupSnapshot.value as Map<dynamic, dynamic>;
          _currentGroupName = groupData['groupName'];
          _joinCode = groupData['joinCode'];
        }
      }

      // 2. Ambil data SEMUA grup (ID & Nama)
      final allGroupsSnapshot = await _dbRef.child('groups').get();
      if (allGroupsSnapshot.exists) {
        _processGroupNames(allGroupsSnapshot);
      }
      
      // 3. Ambil data SEMUA user (untuk nama anggota grup sendiri)
      final allUsersSnapshot = await _dbRef.child('users').get();
      if (allUsersSnapshot.exists) {
        _allUsers = Map<String, dynamic>.from(allUsersSnapshot.value as Map);
      }

      // 4. Ambil data JADWAL PIKET GLOBAL
      final scheduleSnapshot = await _dbRef.child('global_duty_roster').get();
      if (scheduleSnapshot.exists) {
        _globalSchedule = Map<String, dynamic>.from(scheduleSnapshot.value as Map);
      }

    } catch (e) {
      print("Error loading initial data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memuat data: $e")));
      }
    }
    
    setState(() => _isLoading = false);
  }

  // --- REVISI: Pisahkan listener agar lebih rapi ---
  void _setupListeners() {
    if (_userId == null) return;
    
    // 1. Dengar perubahan grup PENGGUNA
    _userGroupSubscription = _dbRef.child('users/$_userId/groupID').onValue.listen((event) {
      // Jika ada perubahan (misal baru gabung/keluar), muat ulang semua data
      _loadInitialData();
    });

    // 2. Dengar perubahan data SEMUA GRUP (jika ada grup baru/ganti nama)
    _allGroupsSubscription = _dbRef.child('groups').onValue.listen((event) {
      if (event.snapshot.exists) {
        _processGroupNames(event.snapshot);
        if (mounted) setState(() {}); // Update UI
      }
    });
    
    // 3. Dengar perubahan data SEMUA USER (jika ada user baru/ganti nama)
    _allUsersSubscription = _dbRef.child('users').onValue.listen((event) {
       if (event.snapshot.exists && mounted) {
        setState(() {
          _allUsers = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    });

    // 4. Dengar perubahan JADWAL PIKET GLOBAL
    _scheduleSubscription = _dbRef.child('global_duty_roster').onValue.listen((event) {
      if (event.snapshot.exists) {
        setState(() {
          _globalSchedule = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      } else {
        setState(() {
          _globalSchedule = {}; // Kosongkan jika dihapus
        });
      }
    });
  }

  // Helper untuk memproses nama grup
  void _processGroupNames(DataSnapshot snapshot) {
    final Map<String, String> tempGroupNames = {};
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    data.forEach((key, value) {
      if (value is Map && value['groupName'] != null) {
        tempGroupNames[key] = value['groupName'] as String;
      }
    });
    setState(() {
      _allGroupNames = tempGroupNames;
    });
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  // --- FUNGSI LAMA (Create, Join, Leave) ---
  // (Tidak berubah, tapi saya pastikan mereka me-refresh data jika berhasil)

  Future<void> _createGroup() async {
    if (_groupNameController.text.isEmpty || _userId == null) return;

    final newGroupId = _dbRef.child('groups').push().key;
    final joinCode = _generateJoinCode();

    final Map<String, dynamic> groupData = {
      'groupName': _groupNameController.text,
      'joinCode': joinCode,
      'members': { _userId!: true }
    };
    
    Map<String, dynamic> updates = {};
    updates['/groups/$newGroupId'] = groupData;
    updates['/users/$_userId/groupID'] = newGroupId;

    await _dbRef.update(updates);
    
    _groupNameController.clear();
    // _loadInitialData(); // Tidak perlu, listener _userGroupSubscription akan jalan
  }

  Future<void> _joinGroup() async {
    if (_joinCodeController.text.isEmpty || _userId == null) return;

    final query = _dbRef.child('groups').orderByChild('joinCode').equalTo(_joinCodeController.text);
    final snapshot = await query.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final groupId = data.keys.first;
      
      Map<String, dynamic> updates = {};
      updates['/users/$_userId/groupID'] = groupId;
      updates['/groups/$groupId/members/$_userId'] = true;

      await _dbRef.update(updates);
      
      _joinCodeController.clear();
      // _loadInitialData(); // Tidak perlu, listener _userGroupSubscription akan jalan
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kode kelompok tidak ditemukan.")));
    }
  }

  Future<void> _leaveGroup() async {
    if (_userId == null || _currentGroupId == null) return;

    Map<String, dynamic> updates = {};
    updates['/users/$_userId/groupID'] = null; 
    updates['/groups/$_currentGroupId/members/$_userId'] = null;

    await _dbRef.update(updates);
    
    // Reset state lokal (listener akan otomatis handle sisanya)
    setState(() {
      _currentGroupId = null;
      _currentGroupName = null;
      _joinCode = null;
    });
  }
  
  // --- Akhir Fungsi Lama ---


  // --- REVISI BESAR: Tampilan UI ---
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: kBackgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Manajemen Kelompok"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(
            color: Colors.black87,
          ),
          titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Bagian 1: Info Grup Saat Ini ATAU Gabung/Buat
                    if (_currentGroupId == null)
                      _buildJoinOrCreateUI()
                    else
                      _buildGroupInfoUI(), // Ini UI untuk info grup sendiri
                    
                    const SizedBox(height: 20),
                    const Divider(thickness: 1, color: Colors.black26),
                    const SizedBox(height: 20),

                    // --- REVISI: Bagian 2: Jadwal Piket Global ---
                    _buildGlobalScheduleUI(), // Ini UI baru untuk jadwal
                  ],
                ),
              ),
      ),
    );
  }

  // UI untuk gabung/buat grup (Tidak Berubah)
  Widget _buildJoinOrCreateUI() {
    return Column(
      children: [
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text("Gabung Kelompok", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: _joinCodeController,
                  decoration: const InputDecoration(labelText: "Masukkan Kode Gabung"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _joinGroup, child: const Text("Gabung")),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        const Text("ATAU", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 30),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text("Buat Kelompok Baru", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(labelText: "Nama Kelompok Baru"),
                ),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: _createGroup, child: const Text("Buat")),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- REVISI: UI ini sekarang HANYA menampilkan info grup sendiri ---
  Widget _buildGroupInfoUI() {
    // --- Variabel 'myGroupMembers' dan blok 'if' yang tidak terpakai sudah dihapus ---
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Kartu 1: Info Grup Saya (Tidak Berubah) ---
        const Text("Kelompok Saya:", style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(_currentGroupName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            subtitle: Text("Kode Gabung: $_joinCode"),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                if (_joinCode != null) {
                  Clipboard.setData(ClipboardData(text: _joinCode!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kode disalin!")));
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // --- Kartu 2: Daftar Anggota Grup Saya (Tidak Berubah) ---
        _buildMyGroupMembersList(),
        
        const SizedBox(height: 30),
        Center(
          child: TextButton(
            onPressed: _leaveGroup,
            style: TextButton.styleFrom(
              backgroundColor: Colors.red[50],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text("Keluar dari Kelompok", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
  
  // Widget helper untuk menampilkan anggota grup sendiri
  Widget _buildMyGroupMembersList() {
    // Ambil data anggota grup sendiri dari _allUsers
    // --- Variabel 'myGroupData' yang tidak terpakai sudah dihapus ---
    if (_currentGroupId != null && _allUsers.isNotEmpty) {
      // Kita akan asumsikan _allUsers adalah /users
      // Ambil data anggota dari _allUsers yang punya groupID sama
      
      final List<String> memberNames = [];
      _allUsers.forEach((userId, userData) {
        if (userData is Map && userData['groupID'] == _currentGroupId) {
          memberNames.add(userData['name'] ?? 'Anggota (tanpa nama)');
        }
      });

      if (memberNames.isEmpty) {
        // Ini bisa terjadi sesaat jika _allUsers belum ter-update
        return const Text("Memuat data anggota...");
      }
      
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          title: Text("Anggota (${memberNames.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
          initiallyExpanded: false, // Tutup by default
          childrenPadding: const EdgeInsets.only(bottom: 10),
          children: memberNames.map((name) {
            return ListTile(
                dense: true,
                leading: const Icon(Icons.person_outline, size: 20),
                title: Text(name),
              );
          }).toList(),
        ),
      );
    }
    
    return const Text("Tidak dapat memuat daftar anggota.");
  }

  // --- REVISI: UI BARU UNTUK JADWAL PIKET GLOBAL ---
  Widget _buildGlobalScheduleUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Jadwal Piket Mingguan",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        Text(
          "Anggota hanya dapat mengubah jadwal untuk kelompoknya sendiri.",
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 15),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _daysOfWeek.length,
          itemBuilder: (context, index) {
            final day = _daysOfWeek[index]; // e.g., "senin"
            final dayCapitalized = day[0].toUpperCase() + day.substring(1); // e.g., "Senin"
            
            // Ambil ID grup yang terjadwal hari itu
            final Map<String, dynamic> scheduledGroupIds = _globalSchedule.containsKey(day) 
              ? Map<String, dynamic>.from(_globalSchedule[day] as Map) 
              : {};
              
            // Ubah ID menjadi Nama Grup
            final List<String> scheduledGroupNames = [];
            scheduledGroupIds.keys.forEach((groupId) {
              if (_allGroupNames.containsKey(groupId)) {
                scheduledGroupNames.add(_allGroupNames[groupId]!);
              }
            });

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(dayCapitalized, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: scheduledGroupNames.isEmpty
                  ? const Text("Tidak ada kelompok terjadwal", style: TextStyle(fontStyle: FontStyle.italic))
                  : Text(scheduledGroupNames.join(', ')), // Tampilkan "PKK A, PKK B"
                trailing: IconButton(
                  icon: const Icon(Icons.edit_calendar_outlined),
                  color: Theme.of(context).primaryColor,
                  tooltip: "Edit Jadwal Hari $dayCapitalized",
                  onPressed: _currentGroupId == null // Nonaktifkan jika user tidak punya grup
                    ? null
                    : () => _showEditScheduleDialog(day, dayCapitalized),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --- REVISI: FUNGSI DIALOG UNTUK EDIT JADWAL ---
  Future<void> _showEditScheduleDialog(String dayKey, String dayName) async {
    // Ini adalah data yang akan diubah di dalam dialog
    // Kita salin data dari state utama agar perubahan tidak langsung terjadi
    Map<String, bool> scheduleForDay = {};
    _allGroupNames.keys.forEach((groupId) {
      scheduleForDay[groupId] = _globalSchedule[dayKey]?[groupId] ?? false;
    });

    return showDialog(
      context: context,
      builder: (context) {
        // Gunakan StatefulBuilder agar dialog bisa punya state sendiri
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Edit Jadwal Hari $dayName"),
              content: Container(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allGroupNames.length,
                  itemBuilder: (context, index) {
                    final groupId = _allGroupNames.keys.elementAt(index);
                    final groupName = _allGroupNames[groupId]!;
                    final isMyGroup = (groupId == _currentGroupId);
                    
                    return CheckboxListTile(
                      title: Text(groupName),
                      value: scheduleForDay[groupId],
                      // --- INI LOGIKA KUNCI ANDA ---
                      onChanged: isMyGroup 
                        ? (bool? newValue) {
                            // HANYA BISA MENGUBAH GRUP SENDIRI
                            setDialogState(() {
                              scheduleForDay[groupId] = newValue ?? false;
                            });
                          }
                        : null, // Checkbox nonaktif (abu-abu) jika BUKAN grup saya
                      controlAffinity: ListTileControlAffinity.leading,
                      tileColor: isMyGroup ? Colors.green.shade50 : null,
                      secondary: isMyGroup ? const Icon(Icons.lock_open, color: Colors.green) : const Icon(Icons.lock, color: Colors.grey),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () {
                    // --- SIMPAN DATA KE FIREBASE ---
                    // Kita HANYA update data milik grup kita sendiri
                    if (_currentGroupId != null) {
                      final bool myNewStatus = scheduleForDay[_currentGroupId] ?? false;
                      
                      _dbRef
                        .child('global_duty_roster')
                        .child(dayKey)
                        .child(_currentGroupId!)
                        .set(myNewStatus ? true : null); // Hapus (set null) jika false
                    }
                    Navigator.of(context).pop();
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}