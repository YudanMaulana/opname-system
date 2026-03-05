import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'login_page.dart';

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
    cursorColor: Colors.white, // Warna kursor global
    selectionColor: Color(0xFFC3A11D), // Warna saat teks diblok
    selectionHandleColor: Colors.white, // Warna bubble di bawah kursor
  ),
),
      home: const LoginPage(),
    );
  }
}