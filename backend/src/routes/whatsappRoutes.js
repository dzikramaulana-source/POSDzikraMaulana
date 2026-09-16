const express = require('express');
const {
  getPairingPage,
  getStatus,
  getQr,
  searchRecipients,
  sendReceiptDocument,
  logout,
  restart,
} = require('../controllers/whatsappController');
const { protect, authorize } = require('../middleware/auth');
const uploadReceiptPdf = require('../middleware/uploadReceipt');

const router = express.Router();

// Halaman QR (publik, dibuka langsung di browser)
router.get('/', getPairingPage);

router.get('/status', protect, getStatus);
router.get('/qr', protect, getQr);
// Cari nomor pelanggan yang pernah dikirimi struk (autocomplete)
router.get('/recipients', protect, searchRecipients);
// Kirim PDF struk ke nomor WhatsApp pelanggan (field file + phone)
router.post(
  '/send-document',
  protect,
  uploadReceiptPdf.single('file'),
  sendReceiptDocument
);
router.post('/logout', protect, authorize('admin'), logout);
router.post('/restart', protect, authorize('admin'), restart);

module.exports = router;
