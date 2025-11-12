import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // <-- 1. TAMBAHKAN IMPORT
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  
  String _selectedGender = 'Perempuan'; 

  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      _emailController.text = currentUser!.email ?? '';
      
      String displayName = currentUser!.displayName ?? '';
      
      if (displayName.startsWith('Bapak ')) {
        _selectedGender = 'Laki-laki';
        displayName = displayName.substring(6); // Hapus "Bapak "
      } else if (displayName.startsWith('Ibu ')) {
        _selectedGender = 'Perempuan';
        displayName = displayName.substring(4); // Hapus "Ibu "
      }
      
      final nameParts = displayName.split(' ');
      if (nameParts.isNotEmpty) {
        _firstNameController.text = nameParts[0];
        if (nameParts.length > 1) {
          _lastNameController.text = nameParts.sublist(1).join(' ');
        }
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- 2. MODIFIKASI FUNGSI SAVE ---
  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // --- Bagian 1: Update Firebase Auth (Seperti sebelumnya) ---
      final title = _selectedGender == 'Laki-laki' ? 'Bapak' : 'Ibu';
      final name = '${_firstNameController.text} ${_lastNameController.text}'.trim();
      final newDisplayName = '$title $name';
      
      await user.updateDisplayName(newDisplayName);
      await user.reload(); // Muat ulang user untuk dapat data baru

      // --- Bagian 2: Update Realtime Database ---
      // Sesuai permintaan Anda, kita simpan 'name' saja
      final dbRef = FirebaseDatabase.instance.ref();
      final Map<String, dynamic> userData = {
        'name': newDisplayName, // Simpan nama lengkap (Bapak/Ibu ...)
      };
      
      // Gunakan .update() agar tidak menghapus fcmToken atau groupID
      await dbRef.child('users/${user.uid}').update(userData);
      // --- Akhir Bagian 2 ---


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil berhasil diperbarui."), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }

    } on FirebaseAuthException catch (e) {
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Gagal memperbarui profil Auth."), backgroundColor: Colors.red),
        );
        }
    } catch (e) {
      // Tangani error database jika perlu
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memperbarui database: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
  // --- AKHIR MODIFIKASI 2 ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          "User Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black87, // Warna gelap untuk ikon
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildTextField(label: "First Name", controller: _firstNameController),
          const SizedBox(height: 20),
          _buildTextField(label: "Last Name", controller: _lastNameController),
          const SizedBox(height: 20),
          _buildTextField(label: "E-Mail", controller: _emailController, readOnly: true),
          const SizedBox(height: 20),
          _buildGenderSelector(),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfile,
              child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Jenis Kelamin", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
            decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Laki-laki'),
                  value: 'Laki-laki',
                  groupValue: _selectedGender,
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value!;
                    });
                  },
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: const Text('Perempuan'),
                  value: 'Perempuan',
                  groupValue: _selectedGender,
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ],
    );
  }
}
