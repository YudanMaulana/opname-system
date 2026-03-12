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
  final MobileScannerController _controller = MobileScannerController(
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
  
  final TextEditingController _qtyEditController = TextEditingController();
  final TextEditingController _manualSearchController = TextEditingController();

  String? _scannedSku;
  Map<String, dynamic>? _productData;
  String _targetLokasi = 'stok_bawah';
  bool _isSaving = false;
  bool _isFetching = false;
  bool _isCameraRunning = true;
  double _zoomFactor = 0.0;

  final Color primaryGold = const Color(0xFFC3A11D);
  final Color bgDark = const Color(0xFF3F372F);

  // --- 1. FETCH PRODUCT DATA ---
  Future<void> _fetchProduct(String code) async {
    if (_isFetching) return;

    setState(() {
      _isFetching = true;
      _scannedSku = code;
    });

    try {
      final cleanCode = code.trim().toUpperCase();
      final doc = await _db.collection('products').doc(cleanCode).get();

      if (doc.exists) {
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
    setState(() => _productData = null);
    ScaffoldMessenger.of(context).clearSnackBars();
    _showSnackBar("SKU $code Tidak Terdaftar!", Colors.orange);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _productData == null) {
        setState(() => _scannedSku = null);
      }
    });
  }

  // --- 2. SCANNER LOGIC ---
  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.first.rawValue;
    if (_productData != null || !_isCameraRunning) return;

    if (code != null && code != _scannedSku && !_isFetching) {
      _controller.stop(); 
      setState(() => _isCameraRunning = false);
      await _fetchProduct(code);
    }
  }

  void _resumeScanning() {
    setState(() {
      _productData = null;
      _scannedSku = null;
      _isCameraRunning = true;
    });
    _controller.start();
  }

  // --- 3. UPDATE LOGIC (DENGAN SKU LAMA) ---
  Future<void> _processUpdate() async {
    if (_qtyEditController.text.isEmpty) {
      _showSnackBar("Isi jumlah stok baru!", Colors.redAccent);
      return;
    }
    setState(() => _isSaving = true);
    try {
      int oldQty = 0;
      var rawOldQty = _productData![_targetLokasi];
      if (rawOldQty != null) {
        oldQty = (rawOldQty is int) ? rawOldQty : (rawOldQty as num).toInt();
      }

      int newQty = int.tryParse(_qtyEditController.text) ?? 0;
      
      // Mengambil data sku_lama dari document product
      String skuLama = (_productData!['sku_lama'] ?? "-").toString();

      // Update stok di Master Produk
      await _db.collection('products').doc(_scannedSku).update({
        _targetLokasi: newQty,
        'last_updated': FieldValue.serverTimestamp(),
      });

      // Simpan ke Log History (untuk laporan CSV)
      await _db.collection('logs').add({
        'sku': _scannedSku,
        'sku_lama': skuLama, // Menyimpan SKU Lama ke log
        'nama': _productData!['nama'] ?? "Tanpa Nama",
        'lokasi': _targetLokasi,
        'qty_lama': oldQty,
        'qty_baru': newQty,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _showSnackBar("Stok Berhasil Diperbarui!", Colors.green);
      _resumeScanning(); 
    } catch (e) {
      _showSnackBar("Gagal update: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- 4. MANUAL SEARCH MODAL ---
  void _showManualSearch() {
    _manualSearchController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String query = _manualSearchController.text.toUpperCase();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _manualSearchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: primaryGold),
                      hintText: "Cari Nama atau Kode SKU...",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                    onChanged: (value) => setModalState(() {}),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: query.isEmpty
                        ? const Center(child: Text("Masukkan pencarian", style: TextStyle(color: Colors.white24)))
                        : StreamBuilder<QuerySnapshot>(
                            stream: _db.collection('products').snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: primaryGold));

                              var filteredDocs = snapshot.data!.docs.where((doc) {
                                String sku = doc.id.toUpperCase();
                                String skuLama = (doc['sku_lama'] ?? "").toString().toUpperCase();
                                String nama = (doc['nama'] ?? "").toString().toUpperCase();
                                return sku.contains(query) || nama.contains(query) || skuLama.contains(query);
                              }).toList();

                              if (filteredDocs.isEmpty) {
                                return const Center(child: Text("Produk tidak ditemukan", style: TextStyle(color: Colors.white24)));
                              }

                              return ListView.builder(
                                itemCount: filteredDocs.length,
                                itemBuilder: (context, index) {
                                  var data = filteredDocs[index].data() as Map<String, dynamic>;
                                  var docId = filteredDocs[index].id;
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 5),
                                    title: Text(data['nama'] ?? "Tanpa Nama", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    subtitle: Text("SKU: $docId | Lama: ${data['sku_lama'] ?? '-'}", style: TextStyle(color: primaryGold)),
                                    trailing: const Icon(Icons.chevron_right, color: Colors.white24),
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
                  decoration: BoxDecoration(
                    border: Border.all(color: primaryGold, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Positioned(
                  bottom: 10, left: 20, right: 20,
                  child: Row(
                    children: [
                      const Icon(Icons.zoom_out, color: Colors.white),
                      Expanded(
                        child: Slider(
                          value: _zoomFactor,
                          min: 0.0, max: 1.0,
                          activeColor: primaryGold,
                          inactiveColor: Colors.white24,
                          onChanged: (value) {
                            setState(() => _zoomFactor = value);
                            _controller.setZoomScale(value);
                          },
                        ),
                      ),
                      const Icon(Icons.zoom_in, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: bgDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: _productData == null ? _buildEmptyState() : SingleChildScrollView(child: _buildDetailPanel()),
            ),
          ),
        ],
      ),
      floatingActionButton: !_isCameraRunning
          ? FloatingActionButton.extended(
              onPressed: _resumeScanning,
              backgroundColor: primaryGold,
              icon: const Icon(Icons.qr_code_scanner, color: Colors.black),
              label: const Text("SCAN ULANG", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          : null,
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
          label: Text("CARI NAMA / SKU MANUAL", style: TextStyle(color: primaryGold)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: primaryGold.withOpacity(0.3))),
        ),
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
                  Text(
                    _productData!['nama']?.toString().toUpperCase() ?? "TANPA NAMA",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text("SKU: $_scannedSku", style: TextStyle(color: primaryGold, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text(
                        "(${_productData!['sku_lama'] ?? '-'})", 
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(onPressed: _resumeScanning, icon: const Icon(Icons.close, color: Colors.white38)),
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
            filled: true,
            fillColor: Colors.black26,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryGold)),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _processUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGold,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
          decoration: BoxDecoration(
            color: isSelected ? primaryGold : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(title, style: TextStyle(color: isSelected ? Colors.black : Colors.white60, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
      ),
    );
  }

  Widget _stokInfo(String label, dynamic val) {
    int displayVal = 0;
    if (val != null) displayVal = (val is int) ? val : (val as num).toInt();
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
        const SizedBox(height: 4),
        Text("$displayVal", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _manualSearchController.dispose();
    _qtyEditController.dispose();
    _controller.dispose();
    super.dispose();
  }
}