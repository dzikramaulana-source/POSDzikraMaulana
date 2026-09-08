const express = require('express');
const {
  createTransaction,
  getTransactions,
  getTransactionById,
} = require('../controllers/transactionController');
const {
  getTransactionHistory,
} = require('../controllers/transactionHistoryController');
const { protect } = require('../middleware/auth');

const router = express.Router();

router.route('/').get(protect, getTransactions).post(protect, createTransaction);
// Harus dideklarasikan sebelum route /:id agar tidak tertelan sebagai :id
router.get('/history', protect, getTransactionHistory);
router.route('/:id').get(protect, getTransactionById);

module.exports = router;
