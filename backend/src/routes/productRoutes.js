const express = require('express');
const {
  getProducts,
  getProductById,
  getProductByBarcode,
  createProduct,
  updateProduct,
  deleteProduct,
} = require('../controllers/productController');
const { protect, authorize } = require('../middleware/auth');
const upload = require('../middleware/upload');

const router = express.Router();

// Kasir boleh melihat produk (untuk transaksi), hanya admin yang mengubah data
router
  .route('/')
  .get(protect, getProducts)
  .post(protect, authorize('admin'), upload.single('image'), createProduct);

// Lookup barcode untuk fitur scan kasir (didaftarkan sebelum '/:id').
router.get('/barcode/:code', protect, getProductByBarcode);

router
  .route('/:id')
  .get(protect, getProductById)
  .put(protect, authorize('admin'), upload.single('image'), updateProduct)
  .delete(protect, authorize('admin'), deleteProduct);

module.exports = router;
