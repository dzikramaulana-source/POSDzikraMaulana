const Setting = require('../models/Setting');

// Tarif PPN default bila pengaturan belum pernah dibuat (10%).
const DEFAULT_TAX_RATE = 10;

// Ambil dokumen pengaturan (buat dengan nilai default bila belum ada).
const getOrCreateSettings = async () => {
  let settings = await Setting.findOne({ key: 'app' });
  if (!settings) {
    settings = await Setting.create({ key: 'app', taxRate: DEFAULT_TAX_RATE });
  }
  return settings;
};

// Helper: tarif PPN sebagai pecahan (mis. 0.10) untuk perhitungan transaksi.
const getTaxRate = async () => {
  const settings = await getOrCreateSettings();
  const rate = Number(settings.taxRate);
  return Number.isFinite(rate) && rate >= 0 ? rate / 100 : DEFAULT_TAX_RATE / 100;
};

// @desc    Ambil pengaturan sistem
// @route   GET /api/settings
// @access  Private
const getSettings = async (req, res) => {
  try {
    const settings = await getOrCreateSettings();
    res.json({ settings: { taxRate: settings.taxRate } });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Perbarui pengaturan sistem
// @route   PUT /api/settings
// @access  Private (admin)
const updateSettings = async (req, res) => {
  try {
    const { taxRate } = req.body;
    const rate = Number(taxRate);

    if (!Number.isFinite(rate) || rate < 0 || rate > 100) {
      return res.status(400).json({ message: 'Tarif PPN harus berupa angka 0 - 100' });
    }

    const settings = await Setting.findOneAndUpdate(
      { key: 'app' },
      { taxRate: rate },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    );

    res.json({
      message: 'Pengaturan disimpan',
      settings: { taxRate: settings.taxRate },
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = { getSettings, updateSettings, getTaxRate };
