import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
  if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
    _showSnackBar("Email dan Password tidak boleh kosong", Colors.orange);
    return;
  }

  setState(() => _isLoading = true);

  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
    
    _showSnackBar("Login Berhasil!", Colors.green);

    // PINDAH KE HALAMAN HOME
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
    
  } on FirebaseAuthException catch (e) {
    String message = "Terjadi kesalahan";
    if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
      message = "Email atau Password salah.";
    } else if (e.code == 'invalid-email') {
      message = "Format email salah.";
    }
    _showSnackBar(message, Colors.redAccent);
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3F372F),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  
                  // Logo
                  Image.asset(
                    'images/logo.png', // Pastikan path ini sesuai dengan pubspec.yaml
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.inventory_2_outlined, size: 80, color: Color(0xFFC3A11D));
                    },
                  ),
                  const Text(
                    "LOGIN",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  const Text(
                    "STOCK CHECK MERCHANDISE STORE",
                    style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  
                  _buildTextField(
                    controller: _emailController,
                    label: "Email", 
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  
                  _buildTextField(
                    controller: _passwordController, 
                    label: "Password", 
                    icon: Icons.lock, 
                    isObscure: true
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC3A11D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading 
                        ? const SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(color: Color(0xFF3F372F), strokeWidth: 2)
                          )
                        : const Text(
                            "SIGN IN", 
                            style: TextStyle(color: Color(0xFF3F372F), fontWeight: FontWeight.bold)
                          ),
                    ),
                  ),
                ],
              ),
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

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      cursorColor: Colors.white, // MEMBUAT KURSOR JADI PUTIH
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFC3A11D)),
        prefixIcon: Icon(icon, color: const Color(0xFFC3A11D)),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC3A11D))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFC3A11D))),
      ),
    );
  }
}