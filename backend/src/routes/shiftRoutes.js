const express = require('express');
const {
  openShift,
  getCurrentShift,
  getShifts,
  getShiftDetail,
  closeShift,
} = require('../controllers/shiftController');
const { protect } = require('../middleware/auth');

const router = express.Router();

// Urutan penting: /current harus sebelum /:id
router.post('/open', protect, openShift);
router.get('/current', protect, getCurrentShift);
router.get('/', protect, getShifts);
router.get('/:id', protect, getShiftDetail);
router.post('/close/:id', protect, closeShift);

module.exports = router;
