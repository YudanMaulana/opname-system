import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

// --- IMPORT HALAMAN TERKAIT ---
import 'scanner_page.dart'; 
import 'tambah_barang.dart';
import 'preview_page.dart'; 
import 'login_page.dart'; // PASTIKAN FILE INI SUDAH ADA

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // --- 1. FUNGSI LOGOUT (DIPERBARUI DENGAN NAVIGASI KE LOGIN) ---
  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: const Color(0xFF3F372F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                "Konfirmasi Keluar",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              const Text(
                "Apakah Anda yakin ingin mengakhiri sesi ini?",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(c),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white10),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Batal", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        // 1. Proses Sign Out dari Firebase
                        await FirebaseAuth.instance.signOut();
                        
                        if (context.mounted) {
                          // 2. Tampilkan SnackBar
                          _showSnackBar(context, "Berhasil keluar", Colors.orange);
                          
                          // 3. Navigasi Paksa ke LoginPage dan hapus semua history page
                          Navigator.pushAndRemoveUntil(
                            context, 
                            MaterialPageRoute(builder: (context) => const LoginPage()), 
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC3A11D),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Keluar", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. FUNGSI AMBIL DATA & BUKA PREVIEW ---
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

  // --- 3. FUNGSI EKSPOR KE CSV ---
  Future<void> _prosesEkspor(BuildContext context, List<QueryDocumentSnapshot> logs) async {
    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
        if (await Permission.manageExternalStorage.isDenied) {
          await Permission.manageExternalStorage.request();
        }
      }

      String csvContent = "WAKTU,SKU,NAMA BARANG,LOKASI,STOK AWAL,STOK BARU,SELISIH\n";
      for (var log in logs) {
        final data = log.data() as Map<String, dynamic>;
        final DateTime waktu = (data['timestamp'] as Timestamp).toDate();
        final String formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(waktu);
        
        String nama = (data['nama'] ?? "-").toString().replaceAll(',', '');
        csvContent += "$formattedDate,${data['sku']},$nama,${data['lokasi']},${data['qty_lama']},${data['qty_baru']},${(data['qty_baru']??0)-(data['qty_lama']??0)}\n";
      }

      Directory? downloadDir;
      if (Platform.isAndroid) {
        downloadDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadDir = await getDownloadsDirectory();
      }

      if (downloadDir == null || !await downloadDir.exists()) {
        downloadDir = await getApplicationDocumentsDirectory();
      }

      final String fileName = "Laporan_Opname_${DateFormat('ddMMyy_HHmm').format(DateTime.now())}.csv";
      final File file = File("${downloadDir.path}/$fileName");
      
      await file.writeAsString(csvContent);

      if (context.mounted) {
        _showSnackBar(context, "Tersimpan di: ${file.path}", Colors.green);
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)], text: 'Laporan Opname');
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      _showSnackBar(context, "Error: $e", Colors.red);
    }
  }

  // --- 4. FUNGSI RESET TOTAL ---
  Future<void> _resetTotalData(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFFC3A11D))),
      );

      final firestore = FirebaseFirestore.instance;
      WriteBatch batch = firestore.batch();

      final logsSnapshot = await firestore.collection('logs').get();
      for (var doc in logsSnapshot.docs) { batch.delete(doc.reference); }

      final productsSnapshot = await firestore.collection('products').get();
      for (var doc in productsSnapshot.docs) { batch.delete(doc.reference); }
      
      await batch.commit();
      
      if (!context.mounted) return;
      Navigator.pop(context); 
      Navigator.pop(context); 

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
    final User? user = FirebaseAuth.instance.currentUser;
    final String userDisplayName = user?.email ?? "User";

    return Scaffold(
      backgroundColor: const Color(0xFF3F372F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0xFFC3A11D),
                          child: Icon(Icons.person, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Halo,", style: TextStyle(color: Colors.white60, fontSize: 12)),
                              Text(
                                userDisplayName, 
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                    tooltip: "Logout",
                  )
                ],
              ),
            ),
            
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
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
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
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