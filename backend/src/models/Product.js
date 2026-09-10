const mongoose = require('mongoose');

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

// Index text untuk pencarian produk
productSchema.index({ name: 'text', sku: 'text' });

module.exports = mongoose.model('Product', productSchema);
