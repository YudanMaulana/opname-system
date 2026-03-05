# 📦 Opname System - IT-XQUEST Merchandise

Aplikasi Manajemen Inventaris (Stock Opname) berbasis **Flutter** dan **Firebase**. Aplikasi ini dirancang untuk mempercepat proses pengecekan stok barang di gudang/toko menggunakan pemindaian QR/Barcode, pencatatan otomatis ke Cloud Firestore, dan ekspor laporan ke format CSV.

## 🚀 Fitur Utama

-   **Smart Scan & Update**: Memperbarui stok barang secara real-time dengan memindai kode SKU.
-   **Master Data Management**: Menambah dan mengelola master barang langsung dari aplikasi.
-   **Preview Laporan**: Melihat riwayat aktivitas opname yang dikelompokkan berdasarkan bulan.
-   **Ekspor CSV**: Menghasilkan laporan stok dalam format `.csv` dan menyimpannya langsung ke folder Download atau membagikannya via WhatsApp/Email.
-   **Bulk Import**: Script Node.js untuk memasukkan ribuan data SKU sekaligus dari file Excel/CSV ke Firestore.
-   **Cloud Sync**: Sinkronisasi data multi-perangkat menggunakan Google Firebase.

## 🛠️ Teknologi yang Digunakan

-   **Framework**: [Flutter](https://flutter.dev/) (Dart)
-   **Database**: [Google Cloud Firestore](https://firebase.google.com/docs/firestore)
-   **Scripting**: [Node.js](https://nodejs.org/) (untuk Bulk Import)
-   **Library Penting**:
    -   `cloud_firestore`: Integrasi Database.
    -   `intl`: Pemformatan tanggal & waktu.
    -   `share_plus`: Berbagi file laporan.
    -   `path_provider` & `permission_handler`: Manajemen penyimpanan file.

## 📂 Struktur Proyek

```text
lib/
├── home.dart            # Halaman utama & logika ekspor
├── scanner_page.dart    # Fitur scan QR/Barcode
├── tambah_barang.dart   # Form input master barang baru
└── preview_page.dart    # Riwayat & preview data sebelum diekspor

scripts/
└── import_batch.js      # Script Node.js untuk bulk import data SKU