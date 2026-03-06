import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Tambahkan import ini
import 'login_page.dart';
import 'home.dart'; // Pastikan import HomePage ada di sini

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const OpnameApp());
}

class OpnameApp extends StatelessWidget {
  const OpnameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Opname Merchandise',
      theme: ThemeData(
        primarySwatch: Colors.amber,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Color(0xFFC3A11D),
          selectionHandleColor: Colors.white,
        ),
      ),
      // --- LOGIKA PENYIMPANAN SESI (PERSISTENCE) ---
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. Jika aplikasi sedang mengecek status (loading)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF3F372F),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFC3A11D)),
              ),
            );
          }
          
          // 2. Jika user sudah pernah login (Sesi Aktif)
          if (snapshot.hasData) {
            return const HomePage();
          }
          
          // 3. Jika user belum login atau sudah logout
          return const LoginPage();
        },
      ),
    );
  }
}