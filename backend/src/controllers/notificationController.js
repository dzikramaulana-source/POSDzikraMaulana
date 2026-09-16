const Notification = require('../models/Notification');
const User = require('../models/User');

// Helper: buat satu notifikasi (dipakai juga oleh transactionController)
const createNotification = async ({
  recipient,
  type,
  title,
  body,
  relatedId = '',
}) => {
  return Notification.create({
    recipient,
    type,
    title,
    body,
    relatedId,
  });
};

// @desc    Daftar notifikasi milik user yang login
// @route   GET /api/notifications
// @access  Private
// Query ?type=transaction|stock|broadcast → hanya tipe tsb.
const getNotifications = async (req, res) => {
  try {
    const { type } = req.query;
    const filter = { recipient: req.user._id };
    if (type) filter.type = type;
    const notifications = await Notification.find(filter)
      .sort({ createdAt: -1 })
      .limit(100);
    res.json({ notifications });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Jumlah notifikasi belum dibaca
// @route   GET /api/notifications/unread-count
// @access  Private
const getUnreadCount = async (req, res) => {
  try {
    const unread = await Notification.countDocuments({
      recipient: req.user._id,
      read: false,
    });
    res.json({ unread });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Tandai satu notifikasi sudah dibaca
// @route   PATCH /api/notifications/:id/read
// @access  Private (pemilik)
const markRead = async (req, res) => {
  try {
    const notification = await Notification.findOne({
      _id: req.params.id,
      recipient: req.user._id,
    });
    if (!notification) {
      return res.status(404).json({ message: 'Notifikasi tidak ditemukan' });
    }
    if (!notification.read) {
      notification.read = true;
      await notification.save();
    }
    res.json({ message: 'Notifikasi ditandai dibaca', notification });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Tandai semua notifikasi sudah dibaca
// @route   POST /api/notifications/read-all
// @access  Private
// Query ?type=transaction|stock_low|stock_out|broadcast → hanya tipe tsb.
// Boleh lebih dari satu tipe sekaligus, dipisah koma (mis. stock_low,stock_out).
const markAllRead = async (req, res) => {
  try {
    const { type } = req.query;
    const filter = { recipient: req.user._id, read: false };
    if (type) filter.type = { $in: type.split(',') };
    const result = await Notification.updateMany(filter, { read: true });
    res.json({ message: 'Semua notifikasi ditandai dibaca', modified: result.modifiedCount });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Hapus satu notifikasi
// @route   DELETE /api/notifications/:id
// @access  Private (pemilik)
const deleteNotification = async (req, res) => {
  try {
    const notification = await Notification.findOneAndDelete({
      _id: req.params.id,
      recipient: req.user._id,
    });
    if (!notification) {
      return res.status(404).json({ message: 'Notifikasi tidak ditemukan' });
    }
    res.json({ message: 'Notifikasi dihapus' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Hapus semua notifikasi milik user
// @route   DELETE /api/notifications
// @access  Private
// Query ?type=transaction|stock|broadcast → hanya tipe tsb.
const clearAll = async (req, res) => {
  try {
    const { type } = req.query;
    const filter = { recipient: req.user._id };
    if (type) filter.type = type;
    const result = await Notification.deleteMany(filter);
    res.json({ message: 'Semua notifikasi dihapus', deleted: result.deletedCount });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Kirim pengumuman ke semua kasir (broadcast)
// @route   POST /api/notifications/broadcast
// @access  Private (admin)
const broadcast = async (req, res) => {
  try {
    const { title, body } = req.body;
    if (!body || !body.trim()) {
      return res.status(400).json({ message: 'Isi pengumuman wajib diisi' });
    }

    const kasirList = await User.find({ role: 'kasir' }).select('_id');
    if (kasirList.length === 0) {
      return res.status(400).json({ message: 'Belum ada kasir terdaftar' });
    }

    const docs = kasirList.map((k) => ({
      recipient: k._id,
      type: 'broadcast',
      title: (title && title.trim()) || 'Pengumuman',
      body: body.trim(),
      relatedId: '',
    }));

    await Notification.insertMany(docs);
    res.status(201).json({
      message: 'Pengumuman terkirim ke semua kasir',
      sent: kasirList.length,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

module.exports = {
  createNotification,
  getNotifications,
  getUnreadCount,
  markRead,
  markAllRead,
  deleteNotification,
  clearAll,
  broadcast,
};
