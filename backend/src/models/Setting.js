const mongoose = require('mongoose');

// Dokumen tunggal (singleton) untuk pengaturan sistem.
// key selalu 'app' agar hanya ada satu baris pengaturan.
const settingSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      default: 'app',
      unique: true,
    },
    // Tarif Pajak Pertambahan Nilai (PPN) dalam satuan persen (mis. 10 = 10%).
    taxRate: {
      type: Number,
      default: 10,
      min: 0,
      max: 100,
    },
  },
  {
    timestamps: true,
  }
);

module.exports = mongoose.model('Setting', settingSchema);
