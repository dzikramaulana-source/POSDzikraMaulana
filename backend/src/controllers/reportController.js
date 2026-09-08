const mongoose = require('mongoose');
const Transaction = require('../models/Transaction');
const Product = require('../models/Product');

// Helper: rentang tanggal (awal-akhir hari)
const getDayRange = (dateStr) => {
  const start = new Date(dateStr);
  start.setHours(0, 0, 0, 0);
  const end = new Date(dateStr);
  end.setHours(23, 59, 59, 999);
  return { start, end };
};

// Helper: parse YYYY-MM-DD menjadi Date (awal hari)
const parseDate = (str) => {
  const d = new Date(str);
  if (isNaN(d.getTime())) return null;
  d.setHours(0, 0, 0, 0);
  return d;
};

// Helper: rentang tanggal dari string start/end
const getRange = (startStr, endStr) => {
  const start = parseDate(startStr);
  if (!start) return null;
  const end = endStr ? parseDate(endStr) : null;
  if (end && end < start) return null;
  const endOfDay = end ? new Date(end) : new Date(start);
  endOfDay.setHours(23, 59, 59, 999);
  return { start, end: endOfDay };
};

// Helper: ringkasan agregasi (summary + previousSummary) untuk satu rentang
const buildSummary = async ({ start, end }) => {
  const match = { createdAt: { $gte: start, $lte: end } };

  // Agregasi level transaksi: total, cost, profit, jumlah transaksi
  const [txAgg] = await Transaction.aggregate([
    { $match: match },
    {
      $group: {
        _id: null,
        totalRevenue: { $sum: '$total' },
        totalCost: { $sum: '$totalCost' },
        totalProfit: { $sum: '$profit' },
        totalTransactions: { $sum: 1 },
      },
    },
  ]);

  // Agregasi level item: jumlah unit terjual
  const [itemAgg] = await Transaction.aggregate([
    { $match: match },
    { $unwind: '$items' },
    {
      $group: {
        _id: null,
        unitsSold: { $sum: '$items.qty' },
      },
    },
  ]);

  const totalRevenue = txAgg?.totalRevenue ?? 0;
  const totalTransactions = txAgg?.totalTransactions ?? 0;
  const totalCost = txAgg?.totalCost ?? 0;
  const totalProfit = txAgg?.totalProfit ?? 0;
  const unitsSold = itemAgg?.unitsSold ?? 0;

  return {
    totalRevenue,
    totalTransactions,
    unitsSold,
    averageTransaction: totalTransactions > 0 ? totalRevenue / totalTransactions : 0,
    totalCost,
    totalProfit,
    margin: totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0,
  };
};

// @desc    Laporan harian: ringkasan + top produk
// @route   GET /api/reports/daily?date=YYYY-MM-DD (default: hari ini)
// @access  Private
const getDailyReport = async (req, res) => {
  try {
    const dateStr = req.query.date || new Date().toISOString().slice(0, 10);
    const { start, end } = getDayRange(dateStr);

    const transactions = await Transaction.find({
      createdAt: { $gte: start, $lte: end },
    });

    const totalTransactions = transactions.length;
    const totalRevenue = transactions.reduce((sum, t) => sum + t.total, 0);
    const totalProfit = transactions.reduce((sum, t) => sum + t.profit, 0);

    // Aggregate top produk berdasarkan qty
    const productMap = {};
    transactions.forEach((tx) => {
      tx.items.forEach((item) => {
        if (!productMap[item.name]) {
          productMap[item.name] = { name: item.name, qty: 0, revenue: 0 };
        }
        productMap[item.name].qty += item.qty;
        productMap[item.name].revenue += item.subtotal;
      });
    });

    const topProducts = Object.values(productMap)
      .sort((a, b) => b.qty - a.qty)
      .slice(0, 10);

    // Ringkasan per metode pembayaran
    const paymentSummary = {};
    transactions.forEach((tx) => {
      const method = tx.paymentMethod;
      if (!paymentSummary[method]) {
        paymentSummary[method] = { count: 0, total: 0 };
      }
      paymentSummary[method].count += 1;
      paymentSummary[method].total += tx.total;
    });

    res.json({
      date: dateStr,
      summary: {
        totalTransactions,
        totalRevenue,
        totalProfit,
        averageTransaction: totalTransactions > 0 ? totalRevenue / totalTransactions : 0,
      },
      topProducts,
      paymentSummary,
      transactions,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Laporan periode: ringkasan + perbandingan + grafik + top produk + payment
// @route   GET /api/reports/period?start=YYYY-MM-DD&end=YYYY-MM-DD
// @access  Private
const getPeriodReport = async (req, res) => {
  try {
    const { start: startStr, end: endStr } = req.query;

    const range = getRange(startStr, endStr);
    if (!range) {
      return res
        .status(400)
        .json({ message: 'Format tanggal tidak valid. Gunakan YYYY-MM-DD dan pastikan start <= end' });
    }
    const { start, end } = range;

    const match = { createdAt: { $gte: start, $lte: end } };

    // 1. Ringkasan periode ini
    const summary = await buildSummary({ start, end });

    // 2. Ringkasan periode sebelumnya (durasi sama persis, tepat sebelum start)
    const durationMs = end.getTime() - start.getTime() + 1;
    const prevEnd = new Date(start.getTime() - 1);
    const prevStart = new Date(prevEnd.getTime() - durationMs + 1);
    const previousSummary = await buildSummary({ start: prevStart, end: prevEnd });

    // 3. Data grafik: per tanggal (dipakai untuk bar chart horizontal harian).
    //    Periode satu hari pun digabung per tanggal agar label "Hari Ini"
    //    konsisten; hanya tanggal yang memiliki transaksi yang dikirim.
    const chartDataRaw = await Transaction.aggregate([
      { $match: match },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
          total: { $sum: '$total' },
        },
      },
      { $sort: { _id: 1 } },
    ]);
    const chartData = chartDataRaw.map((d) => ({ label: d._id, total: d.total }));

    // 4. Top produk terlaris (qty)
    const topProducts = await Transaction.aggregate([
      { $match: match },
      { $unwind: '$items' },
      {
        $group: {
          _id: '$items.name',
          name: { $first: '$items.name' },
          qty: { $sum: '$items.qty' },
          revenue: { $sum: '$items.subtotal' },
          cost: { $sum: { $multiply: ['$items.cost', '$items.qty'] } },
        },
      },
      {
        $project: {
          name: 1,
          qty: 1,
          revenue: 1,
          profit: { $subtract: ['$revenue', '$cost'] },
        },
      },
      { $sort: { qty: -1 } },
      { $limit: 10 },
    ]);

    // 5. Ringkasan metode pembayaran
    const paymentSummary = await Transaction.aggregate([
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
    const paymentSummaryMap = {};
    paymentSummary.forEach((p) => {
      paymentSummaryMap[p._id] = { count: p.count, total: p.total };
    });

    res.json({
      start: startStr,
      end: endStr || startStr,
      summary,
      previousSummary,
      chartData,
      topProducts,
      paymentSummary: paymentSummaryMap,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Laporan stok produk (produk dengan stok menipis)
// @route   GET /api/reports/stock?min=5
// @access  Private
const getStockReport = async (req, res) => {
  try {
    const min = parseInt(req.query.min) || 5;
    const products = await Product.find({ stock: { $lte: min } }).sort({ stock: 1 });
    res.json({
      lowStockThreshold: min,
      products,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getDailyReport, getPeriodReport, getStockReport };
