const mongoose = require('mongoose');

const whatsAppRecipientSchema = new mongoose.Schema(
  {
    // Nomor dalam format internasional tanpa "+" (mis. 62812xxxxxxx).
    phone: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    lastUsedAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
  }
);

// Mempercepat pencarian autocomplete berdasarkan nomor terakhir dipakai.
whatsAppRecipientSchema.index({ lastUsedAt: -1 });

module.exports = mongoose.model('WhatsAppRecipient', whatsAppRecipientSchema);
