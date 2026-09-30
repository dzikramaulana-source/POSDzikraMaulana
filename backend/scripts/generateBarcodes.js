/**
 * Generate gambar barcode (PNG) untuk SELURUH produk di MongoDB.
 *
 * Jalankan di command prompt:
 *   cd backend
 *   npm run barcode
 *
 * Hasil:
 *   - File gambar di backend/barcodes/<barcode>.png
 *   - Daftar produk + nomor barcode + preview barcode ASCII di terminal
 *
 * Gambar selalu dibuat dari angka barcode yang tersimpan di database, jadi
 * produk lama maupun baru menghasilkan gambar yang sama setiap kali dijalankan.
 */
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const bwipjs = require('bwip-js');
const Product = require('../src/models/Product');
const { ean13Modules } = require('../src/utils/ean13');

const OUT_DIR = path.join(__dirname, '..', 'barcodes');
const QUIET_ZONE = '        '; // 8 modul zona sunyi di kiri & kanan

// Preview barcode di terminal (beberapa baris agar terlihat seperti barcode).
const asciiBarcode = (bits) => {
  const line =
    QUIET_ZONE +
    bits
      .split('')
      .map((bit) => (bit === '1' ? '\u2588' : ' '))
      .join('') +
    QUIET_ZONE;
  return Array.from({ length: 6 }, () => line).join('\n');
};

const main = async () => {
  await mongoose.connect(process.env.MONGO_URI, {
    serverSelectionTimeoutMS: 5000,
  });

  fs.mkdirSync(OUT_DIR, { recursive: true });

  const products = await Product.find({}).sort({ name: 1 });
  console.log(`Membuat gambar barcode untuk ${products.length} produk...\n`);

  let created = 0;
  const skipped = [];

  for (const product of products) {
    const code = String(product.barcode || '').trim();

    if (!/^\d{13}$/.test(code)) {
      skipped.push(product.name);
      console.log(`! DILEWATI: ${product.name} [${product.sku}] - barcode tidak valid: "${code}"`);
      continue;
    }

    const png = await bwipjs.toBuffer({
      bcid: 'ean13',
      text: code,
      scale: 4,
      height: 14,
      includetext: true,
      textxalign: 'center',
      textsize: 12,
      // Warna eksplisit: batang hitam di atas latar putih (tanpa ini latar
      // transparan sehingga gambar terlihat hitam saat dibuka).
      barcolor: '000000',
      backgroundcolor: 'FFFFFF',
      textcolor: '000000',
      paddingwidth: 10,
      paddingheight: 10,
    });

    const file = path.join(OUT_DIR, `${code}.png`);
    fs.writeFileSync(file, png);
    created += 1;

    console.log(`\u2713 ${product.name}  [${product.sku}]  ${code}`);
    console.log(`  File: ${path.relative(process.cwd(), file)}`);
    console.log(asciiBarcode(ean13Modules(code)));
    console.log('');
  }

  console.log('='.repeat(60));
  console.log(`${created} gambar barcode dibuat di: ${path.relative(process.cwd(), OUT_DIR)}`);
  if (skipped.length > 0) {
    console.log(`Dilewati (barcode belum ada / tidak valid): ${skipped.join(', ')}`);
  }

  await mongoose.disconnect();
  process.exit(0);
};

main().catch(async (error) => {
  console.error('Gagal membuat barcode:', error.message);
  try {
    await mongoose.disconnect();
  } catch (_) {
    // abaikan
  }
  process.exit(1);
});
