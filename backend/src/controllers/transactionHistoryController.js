const mongoose = require('mongoose');
const Transaction = require('../models/Transaction');

// @desc    Riwayat transaksi: filter nomor transaksi, rentang tanggal, kasir, metode bayar
// @route   GET /api/transactions/history
// @access  Private (kasir: miliknya sendiri; admin: semua)
const getTransactionHistory = async (req, res) => {
  try {
    const { invoice, start, end, kasirId, payment } = req.query;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));

    const filter = {};

    // Kasir hanya melihat transaksi sendiri; admin bisa lihat semua / filter kasir
    if (req.user.role === 'kasir') {
      filter.createdBy = req.user._id;
    } else if (kasirId && mongoose.Types.ObjectId.isValid(kasirId)) {
      filter.createdBy = new mongoose.Types.ObjectId(kasirId);
    }

    if (invoice && invoice.trim()) {
      filter.invoiceNumber = { $regex: invoice.trim(), $options: 'i' };
    }

    // Rentang tanggal: start/end dalam format YYYY-MM-DD
    if (start || end) {
      const range = {};
      if (start) {
        const s = new Date(start);
        if (isNaN(s.getTime())) {
          return res.status(400).json({ message: 'Format tanggal start tidak valid' });
        }
        s.setHours(0, 0, 0, 0);
        range.$gte = s;
      }
      if (end) {
        const e = new Date(end);
        if (isNaN(e.getTime())) {
          return res.status(400).json({ message: 'Format tanggal end tidak valid' });
        }
        e.setHours(23, 59, 59, 999);
        range.$lte = e;
      }
      filter.createdAt = range;
    }

    if (payment && ['cash', 'qris', 'debit', 'transfer'].includes(payment)) {
      filter.paymentMethod = payment;
    }

    const [totalDocs] = await Transaction.aggregate([
      { $match: filter },
      { $count: 'total' },
    ]);
    const total = totalDocs?.total ?? 0;
    const totalPages = Math.max(1, Math.ceil(total / limit));

    const transactions = await Transaction.find(filter)
      .populate('createdBy', 'name username')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit);

    res.json({
      transactions,
      page,
      limit,
      total,
      totalPages,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getTransactionHistory };
