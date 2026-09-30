const mongoose = require('mongoose');
const { generateNumericBarcode } = require('../utils/barcode');

const productSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Nama produk wajib diisi'],
      trim: true,
    },
    sku: {
      type: String,
      required: [true, 'SKU wajib diisi'],
      unique: true,
      trim: true,
      uppercase: true,
    },
    // Barcode numerik unik. Dibuat otomatis oleh hook di bawah bila kosong.
    // Index unik + sparse: produk lama yang belum punya barcode (field tidak
    // ada) tidak saling bentrok saat index dibuat, namun barcode yang terisi
    // tetap divalidasi unik di level database.
    barcode: {
      type: String,
      trim: true,
      unique: true,
      sparse: true,
      match: [/^\d+$/, 'Barcode harus berupa angka'],
    },
    price: {
      type: Number,
      required: [true, 'Harga jual wajib diisi'],
      min: [0, 'Harga tidak boleh negatif'],
    },
    cost: {
      type: Number,
      default: 0,
      min: [0, 'Modal tidak boleh negatif'],
    },
    stock: {
      type: Number,
      default: 0,
      min: [0, 'Stok tidak boleh negatif'],
    },
    category: {
      type: String,
      trim: true,
      default: 'Umum',
    },
    image: {
      type: String,
      default: '',
    },
  },
  {
    timestamps: true,
  }
);

// Isi barcode otomatis untuk produk baru (termasuk dari seed) maupun produk
// lama yang belum memilikinya. Keunikan dicek ke database sebelum disimpan.
productSchema.pre('validate', async function () {
  if (this.barcode) return;

  const Model = this.constructor;
  for (let attempt = 0; attempt < 25; attempt++) {
    const candidate = generateNumericBarcode();
    const taken = await Model.exists({ barcode: candidate });
    if (!taken) {
      this.barcode = candidate;
      return;
    }
  }

  throw new Error('Gagal membuat barcode unik, silakan coba lagi');
});

// Index text untuk pencarian produk
productSchema.index({ name: 'text', sku: 'text' });

module.exports = mongoose.model('Product', productSchema);
