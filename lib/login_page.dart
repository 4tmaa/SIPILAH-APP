// lib/login_page.dart
// (GANTI SELURUH ISI FILE DENGAN KODE DI BAWAH INI)

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/main.dart'; // Untuk kBackgroundGradient

// --- REVISI: IMPORT BARU ---
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
// --- AKHIR REVISI ---


class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  // Fungsi _updateUserData (Tidak Berubah, sudah sempurna)
  Future<void> _updateUserData(User user, {String? customName}) async {
    final dbRef = FirebaseDatabase.instance.ref();
    
    Map<String, dynamic> userData = {
      // Gunakan nama dari Google/FB (user.displayName)
      // atau nama dari registrasi email (customName)
      'name': customName ?? user.displayName, 
    };

    userData.removeWhere((key, value) => value == null);

    if (userData.isNotEmpty) {
      await dbRef.child('users/${user.uid}').update(userData);
    }
  }

  // Fungsi reset password (Tidak berubah)
  Future<void> _sendResetEmail(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Masukkan alamat email yang valid."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Link pemulihan telah dikirim ke email Anda."),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Gagal mengirim email."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Fungsi dialog lupa password (Tidak berubah)
  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Lupa Password"),
        content: TextField(
          controller: emailResetController,
          decoration: const InputDecoration(hintText: "Masukkan email Anda"),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text("Kirim"),
            onPressed: () {
              _sendResetEmail(emailResetController.text.trim());
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // Fungsi _submit (Login/Register Email - Tidak berubah)
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (userCredential.user != null) {
          await _updateUserData(userCredential.user!);
        }
      } else {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final user = userCredential.user;
        if (user != null) {
          final nameFromEmail = _emailController.text.split('@')[0];
          final displayName = '$nameFromEmail';
          await user.updateDisplayName(displayName);
          await user.reload();
          await _updateUserData(user, customName: displayName);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Terjadi kesalahan"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // --- REVISI: FUNGSI BARU UNTUK GOOGLE SIGN IN ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // 1. Memulai proses Google Sign-In
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();

      // Jika user membatalkan
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Mendapatkan detail otentikasi
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Membuat kredensial Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign-in ke Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // 5. Sinkronisasi data user (nama) ke Realtime Database
      if (userCredential.user != null) {
        await _updateUserData(userCredential.user!);
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal login dengan Google: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- REVISI: FUNGSI BARU UNTUK FACEBOOK SIGN IN ---
// lib/login_page.dart

  // 🟢 KODE PERBAIKAN (Ganti fungsi ini)
  Future<void> _signInWithFacebook() async {
    setState(() => _isLoading = true);

    try {
      // 1. Memulai proses Facebook Sign-In
      final LoginResult result = await FacebookAuth.instance.login();

      // Jika user membatalkan
      if (result.status != LoginStatus.success) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Mendapatkan Access Token
      final AccessToken accessToken = result.accessToken!;

      // 3. Membuat kredensial Firebase
      // --- INI ADALAH BARIS YANG DIPERBAIKI ---
      final AuthCredential credential =
          FacebookAuthProvider.credential(accessToken.token); // Diubah dari .tokenString

      // 4. Sign-in ke Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // 5. Sinkronisasi data user (nama) ke Realtime Database
      if (userCredential.user != null) {
        await _updateUserData(userCredential.user!);
      }
    
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal login dengan Facebook: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBackgroundGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/sipilah_logo.png',
                    height: 100,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin ? "Selamat Datang" : "Buat Akun Baru",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@')) {
                        return 'Masukkan email yang valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password minimal 6 karakter';
                        }
                        return null;
                      },
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        "Lupa Password?",
                        style: TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submit,
                            child: Text(_isLogin ? "LOGIN" : "REGISTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                          ),
                        ),
                  
                  // --- REVISI: TOMBOL SOSIAL MEDIA ---
                  const SizedBox(height: 20),
                  Text("Atau masuk dengan", style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tombol Google
                      OutlinedButton.icon(
                        icon: Image.asset('assets/images/google-logo.png', height: 20, width: 20), // Asumsi Anda punya logo ini
                        label: const Text("Google"),
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Tombol Facebook
                      OutlinedButton.icon(
                        icon: Image.asset('assets/images/Facebook-Logo.png', height: 20, width: 20), // Asumsi Anda punya logo ini
                        label: const Text("Facebook"),
                        onPressed: _isLoading ? null : _signInWithFacebook,
                         style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                        ),
                      ),
                    ],
                  ),
                  // --- AKHIR REVISI ---

                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                    },
                    child: Text(
                      _isLogin
                          ? "Belum punya akun? Daftar di sini"
                          : "Sudah punya akun? Login",
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}