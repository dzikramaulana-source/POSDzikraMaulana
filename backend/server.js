require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const connectDB = require('./src/config/db');
const authRoutes = require('./src/routes/authRoutes');
const productRoutes = require('./src/routes/productRoutes');
const transactionRoutes = require('./src/routes/transactionRoutes');
const reportRoutes = require('./src/routes/reportRoutes');
const userRoutes = require('./src/routes/userRoutes');
const shiftRoutes = require('./src/routes/shiftRoutes');
const notificationRoutes = require('./src/routes/notificationRoutes');
const whatsappRoutes = require('./src/routes/whatsappRoutes');
const whatsappService = require('./src/services/whatsappService');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// File statis (gambar produk yang diupload)
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'POS API berjalan', docs: '/api' });
});

app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/users', userRoutes);
app.use('/api/shifts', shiftRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/whatsapp', whatsappRoutes);

// Error handler 404
app.use((req, res) => {
  res.status(404).json({ message: `Route tidak ditemukan: ${req.originalUrl}` });
});

// Error handler umum
app.use((err, req, res, next) => {
  console.error(err.stack);
  const status = err.statusCode || (err.name === 'MulterError' ? 400 : 500);
  res.status(status).json({
    message: err.message || 'Terjadi kesalahan server',
  });
});

const PORT = process.env.PORT || 3000;

connectDB().then(() => {
  app.listen(PORT, () => {
    console.log(`Server POS berjalan di http://localhost:${PORT}`);
    // Mulai koneksi WhatsApp di background agar QR langsung tampil di terminal
    // (dan di http://localhost:PORT/api/whatsapp) tanpa memanggil endpoint dulu.
    whatsappService.initialize();
  });
});
