import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PreviewLaporanPage extends StatelessWidget {
  final List<QueryDocumentSnapshot> logs;
  final VoidCallback onExport;
  final VoidCallback onResetAll;
  final VoidCallback onResetStock;

  const PreviewLaporanPage({
    super.key, 
    required this.logs, 
    required this.onExport, 
    required this.onResetAll,
    required this.onResetStock,
  });

  Map<String, List<QueryDocumentSnapshot>> _groupLogsByMonth() {
    Map<String, List<QueryDocumentSnapshot>> grouped = {};
    for (var log in logs) {
      final data = log.data() as Map<String, dynamic>;
      if (data['timestamp'] == null) continue;
      
      final DateTime date = (data['timestamp'] as Timestamp).toDate();
      final String monthKey = DateFormat('MMMM yyyy').format(date);

      grouped.putIfAbsent(monthKey, () => []).add(log);
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
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () => _confirmAction(
              context, 
              "Reset Semua Stok?", 
              "Semua angka stok akan menjadi 0. Data barang tidak akan dihapus.", 
              onResetStock,
              const Color(0xFFC3A11D),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.orangeAccent),
            label: const Text("RESET", 
              style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: "Format All Data",
            icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            onPressed: () => _confirmAction(
              context, 
              "Format All Data?", 
              "SEMUA data master dan riwayat akan dihapus permanen.", 
              onResetAll,
              Colors.red,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: logs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                      itemCount: monthKeys.length,
                      itemBuilder: (context, index) {
                        final String month = monthKeys[index];
                        final List<QueryDocumentSnapshot> monthLogs = groupedData[month]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMonthHeader(month),
                            const SizedBox(height: 10),
                            ...monthLogs.map((log) {
                              final data = log.data() as Map<String, dynamic>;
                              final DateTime waktu = (data['timestamp'] as Timestamp).toDate();
                              return _buildLogTile(data, waktu);
                            }),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(25, 10, 25, MediaQuery.of(context).padding.bottom + 20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: logs.isEmpty ? null : onExport,
                icon: const Icon(Icons.share_rounded, color: Color(0xFF3F372F), size: 20),
                label: const Text("BAGIKAN CSV SEKARANG", 
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF3F372F))
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC3A11D),
                  disabledBackgroundColor: Colors.grey[200],
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMonthHeader(String month) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC3A11D).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, size: 14, color: Color(0xFFC3A11D)),
          const SizedBox(width: 8),
          Text(month.toUpperCase(), 
            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC3A11D), fontSize: 11, letterSpacing: 1)),
        ],
      ),
    );
  }

  void _confirmAction(BuildContext context, String title, String message, VoidCallback action, Color color) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "",
      pageBuilder: (context, a1, a2) => const SizedBox.shrink(),
      transitionBuilder: (context, a1, a2, child) {
        return Transform.scale(
          scale: a1.value,
          child: Opacity(
            opacity: a1.value,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              title: Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 18)),
              content: Text(message, style: const TextStyle(fontSize: 14, color: Colors.black54)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text("BATAL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, 
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    action();
                  }, 
                  child: const Text("YA, LANJUTKAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildLogTile(Map<String, dynamic> data, DateTime waktu) {
    final bool isIncrease = (data['qty_baru'] ?? 0) > (data['qty_lama'] ?? 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['nama'] ?? "Tanpa Nama", 
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF3F372F))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // SKU UTAMA
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                      child: Text(data['sku'] ?? "-", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    // SKU LAMA (Indikator Tambahan)
                    Text("Lama: ${data['sku_lama'] ?? '-'}", 
                      style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    Text(data['lokasi'].toString().replaceAll('stok_', '').toUpperCase(), 
                      style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text("${data['qty_lama']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const Icon(Icons.arrow_right_alt_rounded, size: 16, color: Colors.grey),
                  Text("${data['qty_baru']}", 
                    style: TextStyle(fontWeight: FontWeight.w900, color: isIncrease ? Colors.green : const Color(0xFFC3A11D), fontSize: 15)),
                ],
              ),
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
          Icon(Icons.layers_clear_outlined, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 20),
          Text("BELUM ADA RIWAYAT", 
            style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 8),
          Text("Lakukan update stok untuk melihat data di sini", 
            style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ],
      ),
    );
  }
}