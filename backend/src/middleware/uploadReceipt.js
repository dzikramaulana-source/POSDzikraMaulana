const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Direktori sementara untuk file PDF struk yang akan dikirim.
const receiptDir = path.join(__dirname, '..', '..', 'uploads', 'receipts');
fs.mkdirSync(receiptDir, { recursive: true });

const MAX_SIZE = 10 * 1024 * 1024; // 10MB

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, receiptDir),
  filename: (req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `struk-${unique}.pdf`);
  },
});

// Middleware upload 1 file PDF dengan field name "file".
const uploadReceiptPdf = multer({
  storage,
  limits: { fileSize: MAX_SIZE },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (file.mimetype === 'application/pdf' || ext === '.pdf') {
      return cb(null, true);
    }
    const err = new Error('Hanya file PDF struk yang diizinkan, maks 10MB');
    err.statusCode = 400;
    return cb(err);
  },
});

module.exports = uploadReceiptPdf;
