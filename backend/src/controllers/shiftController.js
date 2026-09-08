const mongoose = require('mongoose');
const Shift = require('../models/Shift');
const Transaction = require('../models/Transaction');

// Helper: agregasi ringkasan transaksi per kasir dalam rentang waktu
const buildShiftSummary = async ({ kasirId, start, end }) => {
  const match = {
    createdBy: mongoose.Types.ObjectId.isValid(kasirId)
      ? new mongoose.Types.ObjectId(kasirId)
      : kasirId,
    createdAt: { $gte: start, $lte: end },
  };

  const rows = await Transaction.aggregate([
    { $match: match },
    {
      $group: {
        _id: '$paymentMethod',
        count: { $sum: 1 },
        total: { $sum: '$total' },
      },
    },
    { $sort: { total: -1 } },
  ]);

  const paymentSummary = rows.map((r) => ({
    method: r._id,
    count: r.count,
    total: r.total,
  }));

  let totalSales = 0;
  let cashSales = 0;
  paymentSummary.forEach((p) => {
    totalSales += p.total;
    if (p.method === 'cash') cashSales += p.total;
  });

  return {
    totalTransactions: rows.reduce((sum, r) => sum + r.count, 0),
    totalSales,
    cashSales,
    paymentSummary,
  };
};

// Helper: hitung kas yang diharapkan (kas awal + penjualan tunai)
const calcExpectedCash = (openingCash, summary) =>
  (openingCash || 0) + (summary?.cashSales || 0);

// @desc    Buka shift baru (otomatis menutup shift lama yang masih buka)
// @route   POST /api/shifts/open
// @access  Private (kasir)
const openShift = async (req, res) => {
  try {
    const { openingCash } = req.body;
    const value = Number(openingCash);
    if (openingCash === undefined || Number.isNaN(value) || value < 0) {
      return res.status(400).json({ message: 'Kas awal wajib diisi dan tidak boleh negatif' });
    }

    const now = new Date();

    // Tutup otomatis shift lama yang masih terbuka milik kasir ini
    const prevShift = await Shift.findOne({
      kasir: req.user._id,
      status: 'open',
    });

    let autoClosed = null;
    if (prevShift) {
      const summary = await buildShiftSummary({
        kasirId: req.user._id,
        start: prevShift.openedAt,
        end: now,
      });
      prevShift.status = 'closed';
      prevShift.closingCash = calcExpectedCash(prevShift.openingCash, summary);
      prevShift.closedAt = now;
      prevShift.autoClosed = true;
      prevShift.summary = summary;
      await prevShift.save();
      autoClosed = { id: prevShift._id, openedAt: prevShift.openedAt };
    }

    const shift = await Shift.create({
      kasir: req.user._id,
      status: 'open',
      openingCash: value,
      openedAt: now,
    });

    const populated = await Shift.findById(shift._id).populate('kasir', 'name username');
    res.status(201).json({
      message: 'Shift dibuka',
      shift: populated,
      autoClosed,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Ambil shift aktif milik kasir (dengan ringkasan live)
// @route   GET /api/shifts/current
// @access  Private (kasir)
const getCurrentShift = async (req, res) => {
  try {
    const shift = await Shift.findOne({
      kasir: req.user._id,
      status: 'open',
    }).populate('kasir', 'name username');

    if (!shift) {
      return res.json({ shift: null, summary: null });
    }

    const summary = await buildShiftSummary({
      kasirId: req.user._id,
      start: shift.openedAt,
      end: new Date(),
    });

    res.json({ shift, summary });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Daftar shift (kasir: miliknya; admin: semua, bisa filter)
// @route   GET /api/shifts
// @access  Private
const getShifts = async (req, res) => {
  try {
    const filter = {};
    if (req.user.role === 'kasir') {
      filter.kasir = req.user._id;
    } else if (req.query.kasirId && mongoose.Types.ObjectId.isValid(req.query.kasirId)) {
      filter.kasir = req.query.kasirId;
    }
    if (req.query.status === 'open' || req.query.status === 'closed') {
      filter.status = req.query.status;
    }

    const shifts = await Shift.find(filter)
      .populate('kasir', 'name username')
      .sort({ openedAt: -1 })
      .limit(100);

    res.json({ shifts });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Helper: siapkan dokumen detail + perhitungan kas
const buildDetail = async (shiftId) => {
  const shift = await Shift.findById(shiftId).populate('kasir', 'name username');
  if (!shift) return null;

  if (shift.status === 'closed') {
    const expectedCash = calcExpectedCash(shift.openingCash, shift.summary);
    const difference =
      shift.closingCash != null ? shift.closingCash - expectedCash : null;
    return { shift, summary: shift.summary, expectedCash, difference };
  }

  // Shift masih buka: ringkasan live + selisih belum bisa dihitung
  const summary = await buildShiftSummary({
    kasirId: shift.kasir._id,
    start: shift.openedAt,
    end: new Date(),
  });
  const expectedCash = calcExpectedCash(shift.openingCash, summary);
  return { shift, summary, expectedCash, difference: null };
};

// @desc    Detail satu shift (ringkasan + rekap kas)
// @route   GET /api/shifts/:id
// @access  Private (pemilik kasir atau admin)
const getShiftDetail = async (req, res) => {
  try {
    const data = await buildDetail(req.params.id);
    if (!data) {
      return res.status(404).json({ message: 'Shift tidak ditemukan' });
    }

    const { shift } = data;
    const isOwner = shift.kasir._id.toString() === req.user._id.toString();
    if (req.user.role !== 'admin' && !isOwner) {
      return res.status(403).json({ message: 'Anda tidak punya izin melihat shift ini' });
    }

    res.json(data);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Tutup shift dengan mencatat kas akhir (uang fisik)
// @route   POST /api/shifts/close/:id
// @access  Private (kasir pemilik shift)
const closeShift = async (req, res) => {
  try {
    const { closingCash } = req.body;
    const value = Number(closingCash);
    if (closingCash === undefined || Number.isNaN(value) || value < 0) {
      return res.status(400).json({ message: 'Kas akhir wajib diisi dan tidak boleh negatif' });
    }

    const shift = await Shift.findById(req.params.id).populate('kasir', 'name username');
    if (!shift) {
      return res.status(404).json({ message: 'Shift tidak ditemukan' });
    }
    if (shift.status !== 'open') {
      return res.status(400).json({ message: 'Shift sudah ditutup' });
    }

    // Hanya kasir pemilik shift yang boleh menutup
    if (shift.kasir._id.toString() !== req.user._id.toString()) {
      return res.status(403).json({ message: 'Anda tidak punya izin menutup shift ini' });
    }

    const now = new Date();
    const summary = await buildShiftSummary({
      kasirId: req.user._id,
      start: shift.openedAt,
      end: now,
    });

    shift.status = 'closed';
    shift.closingCash = value;
    shift.closedAt = now;
    shift.autoClosed = false;
    shift.summary = summary;
    await shift.save();

    const expectedCash = calcExpectedCash(shift.openingCash, summary);
    const difference = value - expectedCash;

    res.json({
      message: 'Shift ditutup',
      shift,
      summary,
      expectedCash,
      difference,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = {
  openShift,
  getCurrentShift,
  getShifts,
  getShiftDetail,
  closeShift,
};
