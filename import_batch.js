const admin = require("firebase-admin");
const fs = require("fs");
const { parse } = require("csv-parse"); // Install: npm install csv-parse

// 1. Inisialisasi Firebase Admin (Gunakan file sertifikat Anda)
const serviceAccount = require("./admin-key.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function importCsvToFirestore() {
    const results = [];
    const filePath = "./databse.csv"; // Nama file CSV Anda

    console.log("Reading CSV file...");

    // 2. Baca file CSV
    fs.createReadStream(filePath)
        .pipe(parse({ columns: true, trim: true }))
        .on("data", (data) => results.push(data))
        .on("end", async () => {
            console.log(`Total data ditemukan: ${results.length} baris.`);

            let batch = db.batch();
            let count = 0;
            const collectionRef = db.collection("products");

            for (const item of results) {
                const sku = item["KODE SKU"]; // Menyesuaikan header CSV
                const nama = item["NAMA SKU"];

                // FILTER KEAMANAN: 
                // Jangan proses jika SKU kosong, null, atau berisi "#N/A"
                if (!sku || sku === "" || sku === "#N/A" || sku.includes("/")) {
                    console.log(`⚠️ Melewatkan data tidak valid: SKU=${sku}, Nama=${nama}`);
                    continue;
                }

                const docRef = collectionRef.doc(sku.trim()); // trim() untuk hapus spasi tak terlihat

                batch.set(docRef, {
                    sku: sku.trim(),
                    nama: nama.trim(),
                    stok_bawah: 0,
                    stok_display: 0,
                    lokasi: "BELUM DISET", // Tambahkan field yang biasanya diminta aplikasi
                    timestamp: admin.firestore.FieldValue.serverTimestamp()
                });

                count++;

                // Simpan per 500 data
                if (count % 500 === 0) {
                    await batch.commit();
                    batch = db.batch();
                    console.log(`📦 Berhasil memproses: ${count} data...`);
                }
            }

            // Commit sisa data yang kurang dari 500
            if (count % 500 !== 0) {
                await batch.commit();
            }

            console.log(`✅ SELESAI! Total ${count} produk berhasil diimport ke Firestore.`);
            process.exit();
        });
}

importCsvToFirestore();