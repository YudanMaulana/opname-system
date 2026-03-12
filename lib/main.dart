import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart'; // Import shorebird
import 'firebase_options.dart'; 
import 'home.dart';
import 'login_page.dart'; 
import 'windows_page.dart'; 

// Inisialisasi Shorebird Updater sesuai referensi kode kamu
final _shorebirdUpdater = ShorebirdUpdater();

void main() async {
  // Wajib untuk inisialisasi plugin native
  WidgetsFlutterBinding.ensureInitialized(); 

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const OpnameApp());
}

class OpnameApp extends StatefulWidget {
  const OpnameApp({super.key});

  @override
  State<OpnameApp> createState() => _OpnameAppState();
}

class _OpnameAppState extends State<OpnameApp> {

  @override
  void initState() {
    super.initState();
    // Jalankan pengecekan update otomatis saat app terbuka (hanya mobile)
    if (!Platform.isWindows) {
      _checkForUpdates();
    }
  }

  // Logika cek update Shorebird yang aman
  Future<void> _checkForUpdates() async {
    try {
      final status = await _shorebirdUpdater.checkForUpdate();
      if (status == UpdateStatus.outdated) {
        await _shorebirdUpdater.update();
        // Update akan aktif saat aplikasi di-restart berikutnya
      }
    } catch (e) {
      debugPrint("Shorebird Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Opname System Admin X-Quest', 
      theme: ThemeData(
        primarySwatch: Colors.amber,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: Color(0xFFC3A11D),
          selectionHandleColor: Colors.white,
        ),
      ),
      home: _getInitialPage(),
    );
  }

  Widget _getInitialPage() {
    // Jika di Windows, langsung ke Dashboard Windows
    if (Platform.isWindows) {
      return const WindowsDashboard();
    }

    // Jika di Mobile, cek status Login Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF3F372F),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFC3A11D)),
            ),
          );
        }
        
        if (snapshot.hasData) {
          return const HomePage();
        }
        
        return const LoginPage();
      },
    );
  }
}