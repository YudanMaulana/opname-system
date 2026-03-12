import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart'; // Wajib import ini

class WindowsDashboard extends StatefulWidget {
  const WindowsDashboard({super.key});

  @override
  State<WindowsDashboard> createState() => _WindowsDashboardState();
}

class _WindowsDashboardState extends State<WindowsDashboard> {
  final Color primaryGold = const Color(0xFFC3A11D);
  final Color bgDark = const Color(0xFF1A1612);
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // === FITUR POPUP BARCODE ===
  void _showBarcodePopup(String code, String title) {
    if (code == "-" || code.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white, // Background putih agar barcode mudah discan
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
            Text(code, style: TextStyle(color: primaryGold, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
        content: SizedBox(
          width: 300,
          height: 150,
          child: BarcodeWidget(
            barcode: Barcode.code128(), // Standar barcode gudang
            data: code,
            width: 300,
            height: 100,
            drawText: false, // Teks sudah ada di title dialog
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("TUTUP", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // === FITUR DELETE ===
  Future<void> _deleteProduct(String docId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("HAPUS DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("Yakin ingin menghapus SKU: $docId?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('products').doc(docId).delete();
              if (mounted) Navigator.pop(context);
              _showSnack("Data Terhapus", Colors.orange);
            },
            child: const Text("HAPUS", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // === FITUR EDIT ===
  void _editProduct(String docId, Map<String, dynamic> data) {
    final skuController = TextEditingController(text: docId);
    final skuLamaController = TextEditingController(text: data['sku_lama'] ?? "");
    final nameController = TextEditingController(text: data['nama'] ?? "");
    final bwhController = TextEditingController(text: data['stok_bawah']?.toString() ?? "0");
    final atsController = TextEditingController(text: data['stok_atas']?.toString() ?? "0");
    final dspController = TextEditingController(text: data['stok_display']?.toString() ?? "0");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("EDIT DATA BARANG", style: TextStyle(color: primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(color: Colors.white10, height: 20),
                _buildTextField(skuController, "KODE SKU", Icons.qr_code),
                _buildTextField(skuLamaController, "SKU LAMA", Icons.history),
                _buildTextField(nameController, "Nama Barang", Icons.inventory),
                Row(
                  children: [
                    Expanded(child: _buildTextField(bwhController, "Bawah", Icons.south, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(atsController, "Atas", Icons.north, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(dspController, "Display", Icons.monitor, isNumber: true)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGold),
            onPressed: () async {
              final newSku = skuController.text.trim();
              final nama = nameController.text.trim().toUpperCase();
              if (newSku.isEmpty || nama.isEmpty) return;

              final updatedData = {
                'nama': nama,
                'sku_lama': skuLamaController.text.trim(),
                'stok_bawah': int.tryParse(bwhController.text) ?? 0,
                'stok_atas': int.tryParse(atsController.text) ?? 0,
                'stok_display': int.tryParse(dspController.text) ?? 0,
                'last_updated': FieldValue.serverTimestamp(),
              };

              if (newSku != docId) {
                WriteBatch batch = FirebaseFirestore.instance.batch();
                batch.set(FirebaseFirestore.instance.collection('products').doc(newSku), updatedData);
                batch.delete(FirebaseFirestore.instance.collection('products').doc(docId));
                await batch.commit();
              } else {
                await FirebaseFirestore.instance.collection('products').doc(docId).update(updatedData);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text("SIMPAN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    final skuController = TextEditingController();
    final skuLamaController = TextEditingController();
    final nameController = TextEditingController();
    final bwhController = TextEditingController(text: "0");
    final atsController = TextEditingController(text: "0");
    final dspController = TextEditingController(text: "0");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("TAMBAH BARANG BARU", style: TextStyle(color: primaryGold, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(skuController, "KODE SKU", Icons.qr_code),
              _buildTextField(skuLamaController, "SKU LAMA", Icons.history),
              _buildTextField(nameController, "Nama Barang", Icons.inventory),
              Row(
                children: [
                  Expanded(child: _buildTextField(bwhController, "Bawah", Icons.arrow_downward, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(atsController, "Atas", Icons.arrow_upward, isNumber: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(dspController, "Display", Icons.monitor, isNumber: true)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("BATAL", style: TextStyle(color: Colors.white70))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryGold),
            onPressed: () async {
              final sku = skuController.text.trim();
              final nama = nameController.text.trim().toUpperCase();
              if (sku.isEmpty || nama.isEmpty) return;

              await FirebaseFirestore.instance.collection('products').doc(sku).set({
                'nama': nama,
                'sku_lama': skuLamaController.text.trim(),
                'stok_bawah': int.tryParse(bwhController.text) ?? 0,
                'stok_atas': int.tryParse(atsController.text) ?? 0,
                'stok_display': int.tryParse(dspController.text) ?? 0,
                'last_updated': FieldValue.serverTimestamp(),
              });
              if(mounted) Navigator.pop(context);
            },
            child: const Text("DAFTARKAN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryGold, size: 18),
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: primaryGold)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: primaryGold,
        elevation: 0,
        // !!! LOGO DI KIRI, JANGAN DIHAPUS !!!
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('images/logo.png', errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.black)),
        ),
        title: const Text("X-QUEST OPNAME ADMIN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: () => setState(() {})),
          const SizedBox(width: 20),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildHeaderStats(),
            const SizedBox(height: 24),
            Expanded(child: _buildProductTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        int totalSKU = snapshot.data?.docs.length ?? 0;
        int totalQty = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalQty += (data['stok_bawah'] as int? ?? 0) + (data['stok_atas'] as int? ?? 0) + (data['stok_display'] as int? ?? 0);
          }
        }
        return Row(
          children: [
            _statCard("TOTAL SKU DATABASE", totalSKU.toString(), Icons.dataset_outlined),
            const SizedBox(width: 16),
            _statCard("TOTAL ITEM (PCS)", totalQty.toString(), Icons.inventory_2_outlined),
            const Spacer(),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Cari SKU atau Nama...",
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text("TAMBAH BARANG", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryGold, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Row(
        children: [
          Icon(icon, color: primaryGold, size: 30),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('products').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['nama'] ?? "").toString().toLowerCase();
            final id = doc.id.toLowerCase();
            final oldSku = (data['sku_lama'] ?? "").toString().toLowerCase();
            return id.contains(_searchQuery) || name.contains(_searchQuery) || oldSku.contains(_searchQuery);
          }).toList();

          return Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
                columns: const [
                  DataColumn(label: Text("KODE SKU (KLIK)", style: TextStyle(color: Colors.orangeAccent))),
                  DataColumn(label: Text("SKU LAMA (KLIK)", style: TextStyle(color: Colors.white54))),
                  DataColumn(label: Text("NAMA ITEM", style: TextStyle(color: Colors.white))),
                  DataColumn(label: Text("BWH", style: TextStyle(color: Colors.white))),
                  DataColumn(label: Text("ATS", style: TextStyle(color: Colors.white))),
                  DataColumn(label: Text("DSP", style: TextStyle(color: Colors.white))),
                  DataColumn(label: Text("AKSI", style: TextStyle(color: Colors.white))),
                ],
                rows: filteredDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final skuBaru = doc.id;
                  final skuLama = data['sku_lama'] ?? "-";

                  return DataRow(cells: [
                    // SKU BARU (KLIK UNTUK BARCODE)
                    DataCell(
                      InkWell(
                        onTap: () => _showBarcodePopup(skuBaru, "BARCODE SKU BARU"),
                        child: Text(skuBaru, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                      )
                    ),
                    // SKU LAMA (KLIK UNTUK BARCODE)
                    DataCell(
                      InkWell(
                        onTap: () => _showBarcodePopup(skuLama, "BARCODE SKU LAMA"),
                        child: Text(skuLama, style: const TextStyle(color: Colors.white54, fontSize: 12, decoration: TextDecoration.underline)),
                      )
                    ),
                    DataCell(Text(data['nama'] ?? "-", style: const TextStyle(color: Colors.white))),
                    DataCell(Text(data['stok_bawah']?.toString() ?? "0", style: const TextStyle(color: Colors.white70))),
                    DataCell(Text(data['stok_atas']?.toString() ?? "0", style: const TextStyle(color: Colors.white70))),
                    DataCell(Text(data['stok_display']?.toString() ?? "0", style: const TextStyle(color: Colors.white70))),
                    DataCell(Row(
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 18), onPressed: () => _editProduct(doc.id, data)),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => _deleteProduct(doc.id)),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}