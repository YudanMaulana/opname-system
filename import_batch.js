const admin = require("firebase-admin");
const fs = require("fs");
const { parse } = require("csv-parse");

// 1. Inisialisasi Firebase Admin
const serviceAccount = require("./admin-key.json");

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function importCsvToFirestore() {
    const results = [];
    const filePath = "./database.csv"; 

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
                // Menyesuaikan Header Baru: NAME, SKU CODE BARU, SKU CODE LAMA
                const nama = item["NAME"];
                const skuBaru = item["SKU CODE BARU"];
                const skuLama = item["SKU CODE LAMA"];

                // FILTER KEAMANAN: 
                // Abaikan jika NAME kosong atau SKU Baru tidak valid
                if (!nama || !skuBaru || skuBaru === "" || skuBaru === "#N/A") {
                    console.log(`⚠️ Melewatkan data tidak valid: Name=${nama}, SKU Baru=${skuBaru}`);
                    continue;
                }

                // Kita gunakan SKU CODE BARU sebagai ID Dokumen agar unik
                const docRef = collectionRef.doc(skuBaru.trim());

                batch.set(docRef, {
                    sku: skuBaru.trim(),
                    sku_lama: skuLama ? skuLama.trim() : "-", // Jika kosong diisi tanda strip
                    nama: nama.trim(),
                    stok_bawah: 0,
                    stok_atas: 0,
                    stok_display: 0,
                    lokasi: "BELUM DISET",
                    timestamp: admin.firestore.FieldValue.serverTimestamp()
                }, { merge: true }); // Menggunakan merge agar tidak menimpa stok yang sudah ada jika re-import

                count++;

                // Simpan per 500 data
                if (count % 500 === 0) {
                    await batch.commit();
                    batch = db.batch();
                    console.log(`📦 Berhasil memproses: ${count} data...`);
                }
            }

            if (count % 500 !== 0) {
                await batch.commit();
            }

            console.log(`✅ SELESAI! Total ${count} produk X-QUEST berhasil diimport.`);
            process.exit();
        });
}

importCsvToFirestore();