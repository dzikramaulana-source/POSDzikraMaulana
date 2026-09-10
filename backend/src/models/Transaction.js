const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema(
  {
    invoiceNumber: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    items: [
      {
        product: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'Product',
          required: true,
        },
        name: { type: String, required: true },
        price: { type: Number, required: true },
        cost: { type: Number, default: 0 },
        qty: { type: Number, required: true, min: 1 },
        subtotal: { type: Number, required: true },
      },
    ],
    total: {
      type: Number,
      required: true,
      min: 0,
    },
    tax: {
      type: Number,
      default: 0,
    },
    subtotal: {
      type: Number,
      default: 0,
    },
    totalCost: {
      type: Number,
      default: 0,
    },
    profit: {
      type: Number,
      default: 0,
    },
    paymentMethod: {
      type: String,
      enum: ['cash', 'qris', 'debit', 'transfer'],
      default: 'cash',
    },
    cashReceived: {
      type: Number,
      default: 0,
    },
    change: {
      type: Number,
      default: 0,
    },
    // Status pembayaran QRIS (payment gateway)
    paymentStatus: {
      type: String,
      enum: ['pending', 'paid', 'failed', 'expired', 'canceled'],
      default: 'pending',
    },
    paymentRef: {
      type: String,
      default: '',
    },
    paidAt: {
      type: Date,
      default: null,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// Index untuk laporan per tanggal
transactionSchema.index({ createdAt: -1 });

module.exports = mongoose.model('Transaction', transactionSchema);
