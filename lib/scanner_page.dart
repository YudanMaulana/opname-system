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
  final TextEditingController _manualSkuController = TextEditingController();

  String? _scannedSku;
  Map<String, dynamic>? _productData;
  String _targetLokasi = 'stok_bawah';
  bool _isSaving = false;
  bool _isFetching = false; 

  final Color primaryGold = const Color(0xFFC3A11D);
  final Color bgDark = const Color(0xFF3F372F);

  // --- FIX: FETCH DATA DENGAN LOGIKA ANTI-DUPLIKAT ---
  Future<void> _fetchProduct(String code) async {
    if (_isFetching) return; // Jangan fetch jika proses sebelumnya belum selesai
    
    setState(() {
      _isFetching = true;
      _scannedSku = code; 
    });

    try {
      // Pastikan code dibersihkan dari spasi/karakter aneh
      final cleanCode = code.trim().toUpperCase();
      final doc = await _db.collection('products').doc(cleanCode).get();
      
      if (doc.exists) {
        // PERBAIKAN: Walaupun nilai field 0, doc.exists akan tetap TRUE
        setState(() {
          _productData = doc.data();
          _qtyEditController.clear();
        });
      } else {
        _handleNotFound(cleanCode);
      }
    } catch (e) {
      _showSnackBar("Gagal mengambil data: $e", Colors.red);
      setState(() => _scannedSku = null);
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _handleNotFound(String code) {
    setState(() {
      _productData = null;
    });
    
    // BUG FIX: Gunakan clearSnackBars agar pesan tidak menumpuk/muncul terus
    ScaffoldMessenger.of(context).clearSnackBars();
    _showSnackBar("SKU $code Tidak Terdaftar!", Colors.orange);
    
    // Jeda 2 detik sebelum mengizinkan scan kode yang sama lagi (Anti-Loop)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _productData == null) {
        setState(() => _scannedSku = null);
      }
    });
  }

  // --- FIX: TRIGGER ON DETECT DENGAN FILTER ---
  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.first.rawValue;
    // Jika sedang dalam panel detail barang, abaikan scan baru agar tidak tumpang tindih
    if (_productData != null) return;

    if (code != null && code != _scannedSku && !_isFetching) {
      await _fetchProduct(code);
    }
  }

  // --- FIX: PROSES UPDATE DENGAN DEFAULT VALUE ---
  Future<void> _processUpdate() async {
    if (_qtyEditController.text.isEmpty) {
      _showSnackBar("Isi jumlah stok baru!", Colors.redAccent);
      return;
    }
    setState(() => _isSaving = true);
    try {
      // PERBAIKAN: Gunakan .toDouble().toInt() atau tryParse untuk menghindari error tipe data
      int oldQty = 0;
      var rawOldQty = _productData![_targetLokasi];
      if (rawOldQty != null) {
        oldQty = (rawOldQty is int) ? rawOldQty : (rawOldQty as num).toInt();
      }

      int newQty = int.tryParse(_qtyEditController.text) ?? 0;

      await _db.collection('products').doc(_scannedSku).update({
        _targetLokasi: newQty,
        'last_updated': FieldValue.serverTimestamp(),
      });

      await _db.collection('logs').add({
        'sku': _scannedSku,
        'nama': _productData!['nama'] ?? "Tanpa Nama",
        'lokasi': _targetLokasi,
        'qty_lama': oldQty,
        'qty_baru': newQty,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Stok Berhasil Diperbarui!", Colors.green);
      
      // Reset state agar siap scan barang selanjutnya
      setState(() {
        _productData = null;
        _scannedSku = null;
      });
    } catch (e) {
      _showSnackBar("Gagal update: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showManualSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _manualSkuController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: primaryGold),
                      hintText: "Ketik Kode SKU...",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    onChanged: (value) => setModalState(() {}),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: _manualSkuController.text.isEmpty
                        ? const Center(child: Text("Masukkan kode produk", style: TextStyle(color: Colors.white24)))
                        : StreamBuilder<QuerySnapshot>(
                            stream: _db.collection('products')
                                .where(FieldPath.documentId, isGreaterThanOrEqualTo: _manualSkuController.text.toUpperCase())
                                .where(FieldPath.documentId, isLessThanOrEqualTo: "${_manualSkuController.text.toUpperCase()}\uf8ff")
                                .limit(10)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                              var results = snapshot.data!.docs;
                              return ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (context, index) {
                                  var data = results[index].data() as Map<String, dynamic>;
                                  var docId = results[index].id;
                                  return ListTile(
                                    title: Text(docId, style: TextStyle(color: primaryGold, fontWeight: FontWeight.bold)),
                                    subtitle: Text(data['nama'] ?? "-", style: const TextStyle(color: Colors.white70)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _fetchProduct(docId);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
        actions: [
          IconButton(icon: const Icon(Icons.keyboard_outlined), onPressed: _showManualSearch),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(border: Border.all(color: primaryGold, width: 2), borderRadius: BorderRadius.circular(20)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(color: bgDark, borderRadius: const BorderRadius.vertical(top: Radius.circular(35))),
              child: _productData == null 
                ? _buildEmptyState()
                : SingleChildScrollView(child: _buildDetailPanel()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.qr_code_scanner, size: 80, color: Colors.white.withOpacity(0.1)),
        const SizedBox(height: 16),
        const Text("SIAP MENERIMA SCAN...", style: TextStyle(color: Colors.white24, letterSpacing: 1.2)),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _showManualSearch,
          icon: Icon(Icons.search, color: primaryGold),
          label: Text("CARI SKU MANUAL", style: TextStyle(color: primaryGold)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: primaryGold.withOpacity(0.3))),
        )
      ],
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
                  Text(_productData!['nama']?.toString().toUpperCase() ?? "TANPA NAMA", 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("SKU: $_scannedSku", style: TextStyle(color: primaryGold, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            IconButton(onPressed: () => setState(() { _productData = null; _scannedSku = null; }), 
              icon: const Icon(Icons.close, color: Colors.white38))
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stokInfo("BAWAH", _productData!['stok_bawah']),
              _stokInfo("ATAS", _productData!['stok_atas']),
              _stokInfo("DISPLAY", _productData!['stok_display']),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const Text("PILIH LOKASI UPDATE", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            _locationOption("Bawah", "stok_bawah"),
            const SizedBox(width: 8),
            _locationOption("Atas", "stok_atas"),
            const SizedBox(width: 8),
            _locationOption("Display", "stok_display"),
          ],
        ),
        const SizedBox(height: 25),
        TextField(
          controller: _qtyEditController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: "Masukkan stok baru",
            hintStyle: const TextStyle(color: Colors.white10),
            filled: true, fillColor: Colors.black26,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryGold)),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _processUpdate,
            style: ElevatedButton.styleFrom(backgroundColor: primaryGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            child: _isSaving ? const CircularProgressIndicator(color: Colors.black) : const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _locationOption(String title, String value) {
    bool isSelected = _targetLokasi == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _targetLokasi = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? primaryGold : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(title, style: TextStyle(color: isSelected ? Colors.black : Colors.white60, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))),
        ),
      ),
    );
  }

  Widget _stokInfo(String label, dynamic val) {
    // FIX: Ambil nilai num lalu ubah ke int untuk keamanan tampilan
    int displayVal = 0;
    if (val != null) {
      displayVal = (val is int) ? val : (val as num).toInt();
    }
    
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)), 
      const SizedBox(height: 4), 
      Text("$displayVal", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
    ]);
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars(); 
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), 
      backgroundColor: color, 
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  void dispose() {
    _manualSkuController.dispose();
    _qtyEditController.dispose();
    _controller.dispose();
    super.dispose();
  }
}