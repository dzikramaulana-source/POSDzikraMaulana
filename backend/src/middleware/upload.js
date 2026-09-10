const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Direktori penyimpanan gambar produk
const productDir = path.join(__dirname, '..', '..', 'uploads', 'products');
fs.mkdirSync(productDir, { recursive: true });

const ALLOWED = ['image/png', 'image/jpeg', 'image/webp', 'image/gif'];
const MAX_SIZE = 2 * 1024 * 1024; // 2MB

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, productDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `p-${unique}${ext}`);
  },
});

// Middleware upload 1 file gambar dengan field name "image"
const uploadProductImage = multer({
  storage,
  limits: { fileSize: MAX_SIZE },
  fileFilter: (req, file, cb) => {
    if (ALLOWED.includes(file.mimetype)) {
      return cb(null, true);
    }
    const err = new Error('Hanya file gambar (JPG/PNG/WebP/GIF) yang diizinkan, maks 2MB');
    err.statusCode = 400;
    return cb(err);
  },
});

module.exports = uploadProductImage;
