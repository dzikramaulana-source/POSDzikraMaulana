const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    type: {
      type: String,
      // stock_low = stok menipis (1-5), stock_out = stok habis (0)
      enum: ['transaction', 'stock_low', 'stock_out', 'broadcast'],
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    body: {
      type: String,
      required: true,
    },
    read: {
      type: Boolean,
      default: false,
    },
    relatedId: {
      type: String,
      default: '',
    },
  },
  {
    timestamps: true,
  }
);

// Index untuk daftar notifikasi per user (belum dibaca dulu)
notificationSchema.index({ recipient: 1, read: 1, createdAt: -1 });

module.exports = mongoose.model('Notification', notificationSchema);
