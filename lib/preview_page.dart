import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Tambahkan package intl di pubspec.yaml jika belum ada

class PreviewLaporanPage extends StatelessWidget {
  final List<QueryDocumentSnapshot> logs;
  final VoidCallback onExport;
  final VoidCallback onReset;

  const PreviewLaporanPage({
    super.key, 
    required this.logs, 
    required this.onExport, 
    required this.onReset
  });

  // Fungsi untuk mengelompokkan logs berdasarkan Bulan (Format: MMMM yyyy)
  Map<String, List<QueryDocumentSnapshot>> _groupLogsByMonth() {
    Map<String, List<QueryDocumentSnapshot>> grouped = {};
    for (var log in logs) {
      final data = log.data() as Map<String, dynamic>;
      final DateTime date = (data['timestamp'] as Timestamp).toDate();
      final String monthKey = DateFormat('MMMM yyyy').format(date); // Contoh: "March 2026"

      if (grouped[monthKey] == null) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupLogsByMonth();
    final monthKeys = groupedData.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF3F372F),
      appBar: AppBar(
        title: const Text("PREVIEW DATA", 
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
            onPressed: () => _confirmReset(context),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: logs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: monthKeys.length,
                      itemBuilder: (context, index) {
                        final String month = monthKeys[index];
                        final List<QueryDocumentSnapshot> monthLogs = groupedData[month]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // HEADER BULAN
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month, size: 18, color: Color(0xFFC3A11D)),
                                  const SizedBox(width: 8),
                                  Text(month.toUpperCase(), 
                                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 13, letterSpacing: 1)),
                                ],
                              ),
                            ),
                            // DAFTAR LOG DI BULAN TERSEBUT
                            ...monthLogs.map((log) {
                              final data = log.data() as Map<String, dynamic>;
                              final DateTime waktu = (data['timestamp'] as Timestamp).toDate();
                              return _buildLogTile(data, waktu);
                            }),
                            const SizedBox(height: 10),
                            const Divider(thickness: 1, color: Color(0xFFF0F0F0)),
                          ],
                        );
                      },
                    ),
            ),
          ),
          
          // TOMBOL EKSPOR (UI DIPERBAIKI)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(25, 10, 25, 30),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.share_rounded, color: Colors.black),
                label: const Text("BAGIKAN CSV SEKARANG", 
                  style: TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.w900, // Font lebih tebal
                    color: Colors.black,
                    letterSpacing: 0.5
                  )
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC3A11D),
                  elevation: 4,
                  shadowColor: const Color(0xFFC3A11D).withOpacity(0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> data, DateTime waktu) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['nama'] ?? "Tanpa Nama", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3F372F))),
                const SizedBox(height: 4),
                Text("${data['sku']} • ${data['lokasi'].toString().replaceAll('stok_', '').toUpperCase()}", 
                  style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${data['qty_lama']} ➔ ${data['qty_baru']}", 
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC3A11D), fontSize: 14)),
              const SizedBox(height: 4),
              Text(DateFormat('dd MMM, HH:mm').format(waktu), 
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text("Belum ada riwayat opname", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text("HAPUS TOTAL?", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        // Update pesan peringatan
        content: const Text(
          "Tindakan ini akan menghapus SEMUA RIWAYAT (logs) dan SEMUA MASTER BARANG (products). Aplikasi akan menjadi kosong seperti baru.",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("BATAL", style: TextStyle(color: Colors.grey))
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onReset(); // Ini akan memicu fungsi di home.dart
            }, 
            child: const Text("YA, RESET TOTAL", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}