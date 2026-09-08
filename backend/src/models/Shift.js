const mongoose = require('mongoose');

const shiftSchema = new mongoose.Schema(
  {
    kasir: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['open', 'closed'],
      default: 'open',
      index: true,
    },
    openingCash: {
      type: Number,
      required: true,
      min: 0,
    },
    closingCash: {
      type: Number,
      default: null,
    },
    openedAt: {
      type: Date,
      required: true,
    },
    closedAt: {
      type: Date,
      default: null,
    },
    autoClosed: {
      type: Boolean,
      default: false,
    },
    // Snapshot ringkasan saat shift ditutup (arsip riwayat)
    summary: {
      totalTransactions: { type: Number, default: 0 },
      totalSales: { type: Number, default: 0 },
      cashSales: { type: Number, default: 0 },
      paymentSummary: [
        {
          method: { type: String },
          count: { type: Number },
          total: { type: Number },
          _id: false,
        },
      ],
    },
  },
  {
    timestamps: true,
  }
);

// Index gabungan untuk pencarian shift aktif per kasir
shiftSchema.index({ kasir: 1, status: 1 });

module.exports = mongoose.model('Shift', shiftSchema);
