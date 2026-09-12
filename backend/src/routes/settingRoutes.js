const express = require('express');
const { getSettings, updateSettings } = require('../controllers/settingController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

router.get('/', protect, getSettings);
router.put('/', protect, authorize('admin'), updateSettings);

module.exports = router;
