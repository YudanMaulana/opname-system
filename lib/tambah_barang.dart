import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class TambahBarangPage extends StatefulWidget {
  const TambahBarangPage({super.key});

  @override
  State<TambahBarangPage> createState() => _TambahBarangPageState();
}

class _TambahBarangPageState extends State<TambahBarangPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MobileScannerController _cameraController = MobileScannerController();
  
  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _qtyBawah = TextEditingController(text: "0");
  final TextEditingController _qtyAtas = TextEditingController(text: "0");
  final TextEditingController _qtyDisplay = TextEditingController(text: "0");
  
  bool _isLoading = false;
  bool _isChecking = false;

  // --- FUNGSI SCAN SKU ---
  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.first.rawValue;
    if (code != null && code != _skuController.text && !_isChecking) {
      setState(() {
        _isChecking = true;
        _skuController.text = code;
      });

      // Cek apakah SKU sudah ada di Firestore
      final doc = await _db.collection('products').doc(code).get();
      if (doc.exists) {
        _showSnackBar("KODE SKU $code SUDAH ADA!", Colors.orange);
        _skuController.clear();
      } else {
        _showSnackBar("SKU Baru Terdeteksi", Colors.blue);
      }
      
      setState(() => _isChecking = false);
    }
  }

  // --- FUNGSI SIMPAN ---
  Future<void> _simpanKeFirestore() async {
    if (_skuController.text.isEmpty || _namaController.text.isEmpty) {
      _showSnackBar("Harap lengkapi SKU dan Nama!", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _db.collection('products').doc(_skuController.text).set({
        'nama': _namaController.text.toUpperCase(),
        'stok_bawah': int.tryParse(_qtyBawah.text) ?? 0,
        'stok_atas': int.tryParse(_qtyAtas.text) ?? 0,
        'stok_display': int.tryParse(_qtyDisplay.text) ?? 0,
        'last_updated': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Barang Berhasil Didaftarkan!", Colors.green);
      
      // Bersihkan form untuk input barang berikutnya
      setState(() {
        _skuController.clear();
        _namaController.clear();
        _qtyBawah.text = "0";
        _qtyAtas.text = "0";
        _qtyDisplay.text = "0";
      });
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3F372F),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFC3A11D)),
        title: const Text("REGISTRASI BARANG BARU", 
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC3A11D))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- 1. KOTAK SCANNER (ATAS) ---
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFC3A11D), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _cameraController,
                    onDetect: _onDetect,
                  ),
                  if (_isChecking)
                    Container(
                      color: Colors.black54,
                      child: const Center(child: CircularProgressIndicator(color: Color(0xFFC3A11D))),
                    ),
                ],
              ),
            ),
          ),

          // --- 2. FORM DATA (BAWAH) ---
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("KODE SKU"),
                    // Update: Teks hint baru & isReadOnly: false agar bisa ketik manual
                    _buildTextField(_skuController, "Ketik Manual Kode", icon: Icons.qr_code, isReadOnly: false),
                    
                    _buildLabel("NAMA BARANG"),
                    // Update: Teks hint baru
                    _buildTextField(_namaController, "Ketik manual Nama SKU", icon: Icons.inventory),

                    const SizedBox(height: 20),
                    _buildLabel("STOK AWAL TIAP LOKASI"),
                    Row(
                      children: [
                        Expanded(child: _buildQtyInput(_qtyBawah, "Bawah")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildQtyInput(_qtyAtas, "Atas")),
                        const SizedBox(width: 10),
                        Expanded(child: _buildQtyInput(_qtyDisplay, "Display")),
                      ],
                    ),

                    const SizedBox(height: 35),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC3A11D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_isLoading || _isChecking) ? null : _simpanKeFirestore,
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("DAFTARKAN KE DATABASE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 15),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {IconData? icon, bool isReadOnly = false}) {
    return TextField(
      controller: controller,
      readOnly: isReadOnly,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        // Update: Opacity rendah (0.3) pada hint text
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFFC3A11D)),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildQtyInput(TextEditingController controller, String label) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF3F372F).withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _skuController.dispose();
    _namaController.dispose();
    _qtyAtas.dispose();
    _qtyBawah.dispose();
    _qtyDisplay.dispose();
    super.dispose();
  }
}