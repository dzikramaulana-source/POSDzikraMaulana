const express = require('express');
const {
  getNotifications,
  getUnreadCount,
  markRead,
  markAllRead,
  deleteNotification,
  clearAll,
  broadcast,
} = require('../controllers/notificationController');
const { protect, authorize } = require('../middleware/auth');

const router = express.Router();

// Urutan penting: rute statis (/unread-count, /read-all, /broadcast) sebelum /:id
router.get('/', protect, getNotifications);
router.get('/unread-count', protect, getUnreadCount);
router.post('/read-all', protect, markAllRead);
router.post('/broadcast', protect, authorize('admin'), broadcast);
router.patch('/:id/read', protect, markRead);
router.delete('/', protect, clearAll);
router.delete('/:id', protect, deleteNotification);

module.exports = router;
