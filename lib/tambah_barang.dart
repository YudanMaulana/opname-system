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
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.codabar,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.itf,
    ],
    cameraResolution: const Size(1920, 1080),
  );

  final TextEditingController _skuController = TextEditingController();
  final TextEditingController _skuLamaController = TextEditingController(); // Controller Baru
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _qtyBawah = TextEditingController(text: "0");
  final TextEditingController _qtyAtas = TextEditingController(text: "0");
  final TextEditingController _qtyDisplay = TextEditingController(text: "0");

  bool _isLoading = false;
  bool _isChecking = false;
  bool _isCameraRunning = true;
  double _zoomFactor = 0.0;

  // --- FUNGSI SCAN SKU ---
  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.first.rawValue;
    if (code != null &&
        code != _skuController.text &&
        !_isChecking &&
        _isCameraRunning) {
      
      setState(() {
        _isChecking = true;
        _isCameraRunning = false;
        _skuController.text = code.trim().toUpperCase();
      });
      
      await _cameraController.stop();

      try {
        final doc = await _db.collection('products').doc(_skuController.text).get();
        if (doc.exists) {
          _showSnackBar("KODE SKU ${_skuController.text} SUDAH ADA!", Colors.orange);
          _skuController.clear();
          _resumeScanning();
        } else {
          _showSnackBar("SKU Baru Terdeteksi", Colors.blue);
        }
      } catch (e) {
        _showSnackBar("Gagal mengecek data: $e", Colors.red);
      } finally {
        if (mounted) setState(() => _isChecking = false);
      }
    }
  }

  void _resumeScanning() {
    setState(() {
      _skuController.clear();
      _isCameraRunning = true;
    });
    _cameraController.start();
  }

  // --- FUNGSI SIMPAN ---
  Future<void> _simpanKeFirestore() async {
    final sku = _skuController.text.trim().toUpperCase();
    final skuLama = _skuLamaController.text.trim().toUpperCase();
    final nama = _namaController.text.trim().toUpperCase();

    if (sku.isEmpty || nama.isEmpty) {
      _showSnackBar("Harap lengkapi SKU dan Nama!", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _db.collection('products').doc(sku).set({
        'nama': nama,
        'sku_lama': skuLama.isEmpty ? "-" : skuLama, // Simpan SKU Lama
        'stok_bawah': int.tryParse(_qtyBawah.text) ?? 0,
        'stok_atas': int.tryParse(_qtyAtas.text) ?? 0,
        'stok_display': int.tryParse(_qtyDisplay.text) ?? 0,
        'last_updated': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Barang Berhasil Didaftarkan!", Colors.green);

      setState(() {
        _namaController.clear();
        _skuLamaController.clear();
        _qtyBawah.text = "0";
        _qtyAtas.text = "0";
        _qtyDisplay.text = "0";
      });
      _resumeScanning();
    } catch (e) {
      _showSnackBar("Gagal Menyimpan: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3F372F),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFC3A11D)),
        title: const Text(
          "REGISTRASI BARANG BARU",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC3A11D)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- 1. KOTAK SCANNER ---
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isCameraRunning ? const Color(0xFFC3A11D) : Colors.white24, 
                width: 2
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  MobileScanner(controller: _cameraController, onDetect: _onDetect),
                  if (_isChecking)
                    Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Color(0xFFC3A11D)))),
                  Positioned(
                    bottom: 10, left: 20, right: 20,
                    child: Row(
                      children: [
                        const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                        Expanded(
                          child: Slider(
                            value: _zoomFactor,
                            min: 0.0, max: 1.0,
                            activeColor: const Color(0xFFC3A11D),
                            onChanged: (value) {
                              setState(() => _zoomFactor = value);
                              _cameraController.setZoomScale(value);
                            },
                          ),
                        ),
                        const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- 2. FORM DATA ---
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("KODE SKU BARU (HASIL SCAN)"),
                    _buildTextField(_skuController, "Scan atau Ketik Manual", icon: Icons.qr_code, isSku: true),

                    _buildLabel("KODE SKU LAMA (OPSIONAL)"),
                    _buildTextField(_skuLamaController, "Contoh: AD001 / BRG-01", icon: Icons.history, isSku: true),

                    _buildLabel("NAMA BARANG"),
                    _buildTextField(_namaController, "Masukkan Nama Lengkap Barang", icon: Icons.inventory),

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

                    const SizedBox(height: 30),
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPERS ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {IconData? icon, bool isSku = false}) {
    return TextField(
      controller: controller,
      textCapitalization: isSku ? TextCapitalization.characters : TextCapitalization.words,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.2), fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFFC3A11D)),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
          style: const TextStyle(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
    _skuLamaController.dispose();
    _namaController.dispose();
    _qtyAtas.dispose();
    _qtyBawah.dispose();
    _qtyDisplay.dispose();
    super.dispose();
  }
}