import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class SmartScannerPage extends StatefulWidget {
  const SmartScannerPage({super.key});

  @override
  State<SmartScannerPage> createState() => _SmartScannerPageState();
}

class _SmartScannerPageState extends State<SmartScannerPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _qtyEditController = TextEditingController();
  
  String? _scannedSku;
  Map<String, dynamic>? _productData;
  String _targetLokasi = 'stok_bawah'; 
  bool _isSaving = false;

  final Color primaryGold = const Color(0xFFC3A11D);
  final Color bgDark = const Color(0xFF3F372F);

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.first.rawValue;

    // 1. Cek apakah kode ada dan tidak sama dengan yang baru saja discan
    if (code != null && code != _scannedSku) {
      
      // Update _scannedSku SEGERA agar frame berikutnya tidak masuk ke sini lagi
      setState(() {
        _scannedSku = code;
      });

      final doc = await _db.collection('products').doc(code).get();
      
      if (doc.exists) {
        setState(() {
          _productData = doc.data();
          _qtyEditController.clear();
        });
      } else {
        // Jika tidak ada, kita set _productData null tapi _scannedSku tetap terisi
        // agar SnackBar tidak muncul berulang-ulang untuk kode yang sama.
        setState(() {
          _productData = null;
        });
        _showSnackBar("SKU $code Tidak Terdaftar!", Colors.orange);
      }
    }
  }

  Future<void> _processUpdate() async {
    if (_qtyEditController.text.isEmpty) {
      _showSnackBar("Isi jumlah stok baru!", Colors.redAccent);
      return;
    }
    setState(() => _isSaving = true);

    try {
      int oldQty = _productData![_targetLokasi] ?? 0;
      int newQty = int.parse(_qtyEditController.text);

      await _db.collection('products').doc(_scannedSku).update({
        _targetLokasi: newQty,
        'last_updated': FieldValue.serverTimestamp(),
      });

      await _db.collection('logs').add({
        'sku': _scannedSku,
        'nama': _productData!['nama'],
        'lokasi': _targetLokasi,
        'qty_lama': oldQty,
        'qty_baru': newQty,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Stok Berhasil Diperbarui!", Colors.green);
      setState(() {
        _productData = null;
        _scannedSku = null;
      });
    } catch (e) {
      _showSnackBar("Terjadi kesalahan: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("UPDATE STOK", style: TextStyle(color: Colors.white, fontSize: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                // Scanner Overlay (Garis pemandu scan)
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: primaryGold, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              decoration: BoxDecoration(
                color: bgDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, -5))
                ],
              ),
              child: _productData == null 
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, size: 80, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      const Text("SIAP MENERIMA SCAN...", style: TextStyle(color: Colors.white24, letterSpacing: 1.2)),
                    ],
                  )
                : SingleChildScrollView(child: _buildDetailPanel()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_productData!['nama'].toString().toUpperCase(), 
                    style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text("SKU: $_scannedSku", style: TextStyle(color: primaryGold, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _productData = null), 
              icon: const Icon(Icons.close, color: Colors.white38)
            )
          ],
        ),
        const SizedBox(height: 25),
        
        // Stok Info Cards
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stokInfo("BAWAH", _productData!['stok_bawah']),
              Container(width: 1, height: 30, color: Colors.white10),
              _stokInfo("ATAS", _productData!['stok_atas']),
              Container(width: 1, height: 30, color: Colors.white10),
              _stokInfo("DISPLAY", _productData!['stok_display']),
            ],
          ),
        ),
        
        const SizedBox(height: 30),
        const Text("PILIH LOKASI UPDATE", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 12),
        
        // Lokasi Selector (Replacement for Dropdown)
        Row(
          children: [
            _locationOption("Gudang Bawah", "stok_bawah"),
            const SizedBox(width: 8),
            _locationOption("Gudang Atas", "stok_atas"),
            const SizedBox(width: 8),
            _locationOption("Display", "stok_display"),
          ],
        ),

        const SizedBox(height: 25),
        const Text("JUMLAH STOK BARU", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
        const SizedBox(height: 12),
        TextField(
          controller: _qtyEditController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: "Contoh: 50",
            hintStyle: const TextStyle(color: Colors.white10),
            filled: true, 
            fillColor: Colors.black.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryGold)),
          ),
        ),

        const SizedBox(height: 35),
        SizedBox(
          width: double.infinity, height: 60,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _processUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 5,
              shadowColor: primaryGold.withOpacity(0.4),
            ),
            child: _isSaving 
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3)) 
              : const Text("KONFIRMASI UPDATE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _locationOption(String title, String value) {
    bool isSelected = _targetLokasi == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _targetLokasi = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryGold : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? primaryGold : Colors.white10),
          ),
          child: Center(
            child: Text(
              title.split(' ').last, // Ambil kata terakhir saja agar ringkas
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stokInfo(String label, dynamic val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("${val ?? 0}", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }
}