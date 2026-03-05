import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Untuk format tanggal
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' show Permission, PermissionActions, PermissionStatusGetters, PermissionCheckShortcuts;
import 'package:share_plus/share_plus.dart';

// Import halaman terkait (Sesuaikan dengan nama file Anda)
import 'scanner_page.dart'; 
import 'tambah_barang.dart';
import 'preview_page.dart'; 

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // --- 1. FUNGSI AMBIL DATA & BUKA PREVIEW ---
  Future<void> _bukaPreview(BuildContext context) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('logs')
          .orderBy('timestamp', descending: true)
          .get();

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => PreviewLaporanPage(
            logs: snapshot.docs,
            onExport: () => _prosesEkspor(context, snapshot.docs),
            onReset: () => _resetTotalData(context),
          ),
        ),
      );
    } catch (e) {
      _showSnackBar(context, "Gagal memuat data: $e", Colors.red);
    }
  }

  // --- 2. FUNGSI EKSPOR KE CSV (MANUAL STRING BUILDER) ---
  Future<void> _prosesEkspor(BuildContext context, List<QueryDocumentSnapshot> logs) async {
  try {
    // 1. Cek & Request Izin Storage
    if (Platform.isAndroid) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
      
      // Khusus Android 11+, kadang butuh Manage External Storage
      if (await Permission.manageExternalStorage.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }

    // 2. Buat Konten CSV
    String csvContent = "WAKTU,SKU,NAMA BARANG,LOKASI,STOK AWAL,STOK BARU,SELISIH\n";
    for (var log in logs) {
      final data = log.data() as Map<String, dynamic>;
      final DateTime waktu = (data['timestamp'] as Timestamp).toDate();
      final String formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(waktu);
      
      String nama = (data['nama'] ?? "-").toString().replaceAll(',', '');
      csvContent += "$formattedDate,${data['sku']},$nama,${data['lokasi']},${data['qty_lama']},${data['qty_baru']},${(data['qty_baru']??0)-(data['qty_lama']??0)}\n";
    }

    // 3. Cari Folder Download
    Directory? downloadDir;
    if (Platform.isAndroid) {
      downloadDir = Directory('/storage/emulated/0/Download');
    } else {
      downloadDir = await getDownloadsDirectory();
    }

    if (downloadDir == null || !await downloadDir.exists()) {
      // Fallback ke folder internal jika /Download tidak terakses
      downloadDir = await getApplicationDocumentsDirectory();
    }

    final String fileName = "Laporan_Opname_${DateFormat('ddMMyy_HHmm').format(DateTime.now())}.csv";
    final File file = File("${downloadDir.path}/$fileName");
    
    // 4. Tulis File
    await file.writeAsString(csvContent);

    if (context.mounted) {
      _showSnackBar(context, "Tersimpan di: ${file.path}", Colors.green);
      // Opsi: Tetap Share agar user bisa langsung buka/kirim
      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Opname');
    }
    
  } catch (e) {
    _showSnackBar(context, "Error: $e", Colors.red);
  }
}
  // --- 3. FUNGSI RESET TOTAL (MENGHAPUS LOGS & PRODUCTS) ---
  Future<void> _resetTotalData(BuildContext context) async {
    try {
      // Tampilkan loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFFC3A11D))),
      );

      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      // Ambil semua logs
      final logsSnapshot = await firestore.collection('logs').get();
      for (var doc in logsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Ambil semua products
      final productsSnapshot = await firestore.collection('products').get();
      for (var doc in productsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      if (!context.mounted) return;
      Navigator.pop(context); // Tutup loading
      Navigator.pop(context); // Balik ke Home

      _showSnackBar(context, "Database Berhasil Dikosongkan!", Colors.green);
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      _showSnackBar(context, "Gagal reset: $e", Colors.red);
    }
  }

  void _showSnackBar(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: color, 
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3F372F),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'images/logo.png', 
                  height: 90, 
                  errorBuilder: (c, e, s) => const Icon(Icons.inventory_2, size: 80, color: Color(0xFFC3A11D))
                ),
                const SizedBox(height: 15),
                const Text("OPNAME SYSTEM", 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 1.5)
                ),
                const Text("IT-XQUEST MERCHANDISE", 
                  style: TextStyle(color: Color(0xFFC3A11D), fontWeight: FontWeight.w500, fontSize: 12, letterSpacing: 2)
                ),
                const SizedBox(height: 40),

                _buildMenuButton(
                  context,
                  title: "SCAN & UPDATE",
                  subtitle: "Cek & perbarui stok barang",
                  icon: Icons.qr_code_scanner_rounded,
                  color: const Color(0xFFC3A11D),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SmartScannerPage())),
                ),

                const SizedBox(height: 12),

                _buildMenuButton(
                  context,
                  title: "TAMBAH MASTER",
                  subtitle: "Registrasi SKU baru ke database",
                  icon: Icons.add_circle_outline_rounded,
                  color: const Color(0xFF238D9E),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const TambahBarangPage())),
                ),

                const SizedBox(height: 12),

                _buildMenuButton(
                  context,
                  title: "LIHAT & UNDUH",
                  subtitle: "Preview data & ekspor ke CSV",
                  icon: Icons.analytics_outlined,
                  color: Colors.white.withOpacity(0.05),
                  onTap: () => _bukaPreview(context),
                  isOutlined: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, {
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: isOutlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(18),
            border: isOutlined ? Border.all(color: Colors.white10) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.2), size: 14),
            ],
          ),
        ),
      ),
    );
  }
}