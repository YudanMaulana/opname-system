import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  // FIX: Deklarasikan GoogleSignIn di luar fungsi untuk stabilitas
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Pastikan sudah logout dari sesi sebelumnya (mencegah error cache)
      await _googleSignIn.signOut();

      // 2. Inisiasi proses login Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 3. Ambil detail autentikasi
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 4. Buat kredensial Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 5. Masuk ke Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        _showSnackBar("Selamat Datang, ${googleUser.displayName}!", Colors.green);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      // DEBUG: Cetak error ke console untuk melihat detail asli
      print("ERROR GOOGLE SIGNIN: $e");
      _showSnackBar("Gagal Login Google: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI TETAP SAMA SEPERTI SEBELUMNYA
    return Scaffold(
      backgroundColor: const Color(0xFF3F372F),
      body: Column(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Image.asset(
                  'images/logo.png',
                  height: 150,
                  errorBuilder: (context, error, stackTrace) => 
                    const Icon(Icons.inventory_2_outlined, size: 100, color: Color(0xFFC3A11D)),
                ),
                const SizedBox(height: 20),
                const Text(
                  "STOCK CHECK",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28),
                ),
                const Text(
                  "MERCHANDISE STORE",
                  style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 16),
                ),
                const SizedBox(height: 60),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      icon: _isLoading 
                        ? const SizedBox.shrink() 
                        : Image.network(
                            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                            height: 24,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, color: Colors.grey),
                          ),
                      label: _isLoading 
                        ? const CircularProgressIndicator(color: Color(0xFF3F372F))
                        : const Text(
                            "SIGN IN WITH GOOGLE",
                            style: TextStyle(
                              color: Color(0xFF3F372F), 
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 5,
                      ),
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              "© 2026 IT-XQUEST. Licensed Software.",
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}