const Product = require('../models/Product');

// Lengkapi barcode untuk semua produk lama yang belum punya.
// Idempoten: produk yang sudah punya barcode tidak disentuh.
// Dipanggil otomatis saat server start (lihat server.js).
const backfillMissingBarcodes = async () => {
  const products = await Product.find({
    $or: [{ barcode: { $exists: false } }, { barcode: null }, { barcode: '' }],
  });

  let updated = 0;
  for (const product of products) {
    // Hook pre('validate') pada model akan mengisi barcode unik di sini.
    product.barcode = undefined;
    await product.save();
    updated += 1;
  }

  return updated;
};

module.exports = { backfillMissingBarcodes };
