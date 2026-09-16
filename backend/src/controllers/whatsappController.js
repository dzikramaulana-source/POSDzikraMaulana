const fs = require('fs');
const whatsappService = require('../services/whatsappService');
const WhatsAppRecipient = require('../models/WhatsAppRecipient');

// @desc    Halaman untuk menghubungkan akun WhatsApp (menampilkan QR)
// @route   GET /api/whatsapp
// @access  Public (hanya berguna di jaringan lokal)
const getPairingPage = async (req, res) => {
  try {
    whatsappService.initialize();
    const info = whatsappService.getStatus();

    let content;
    if (info.connected) {
      const akun = [info.account?.name, info.account?.number && `(${info.account.number})`]
        .filter(Boolean)
        .join(' ');
      content = `
        <h2 class="ok">WhatsApp Terhubung</h2>
        <p>${akun || 'Akun sudah tertaut'}</p>`;
    } else if (info.qr) {
      content = `
        <h2>Scan QR untuk Menghubungkan</h2>
        <img src="${info.qr}" alt="QR WhatsApp" />
        <p>Buka WhatsApp &gt; Perangkat Tertaut &gt; Tautkan Perangkat, lalu scan QR di atas.</p>
        <p class="muted">Halaman ini menyegarkan otomatis setiap 5 detik.</p>`;
    } else {
      content = `
        <h2>Menyiapkan QR...</h2>
        <p class="muted">Status: ${info.status}. Halaman menyegarkan otomatis.</p>`;
    }

    res.type('html').send(`<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<meta http-equiv="refresh" content="5" />
<title>Hubungkan WhatsApp</title>
<style>
  body { font-family: system-ui, sans-serif; background:#0f172a; color:#e2e8f0; display:flex; min-height:100vh; align-items:center; justify-content:center; margin:0; }
  .card { background:#1e293b; padding:32px; border-radius:16px; text-align:center; max-width:420px; box-shadow:0 10px 40px rgba(0,0,0,.4); }
  h1, h2 { margin:0 0 12px; }
  img { background:#fff; padding:12px; border-radius:12px; width:280px; height:280px; }
  .muted { color:#94a3b8; font-size:14px; }
  .ok { color:#22c55e; }
</style>
</head>
<body>
  <div class="card">
    <h1>Hubungkan WhatsApp</h1>
    ${content}
  </div>
</body>
</html>`);
  } catch (error) {
    res.status(500).send(error.message);
  }
};

// @desc    Status koneksi WhatsApp
// @route   GET /api/whatsapp/status
// @access  Private
const getStatus = async (req, res) => {
  try {
    whatsappService.initialize();
    res.json(whatsappService.getStatus());
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    QR Code untuk menghubungkan akun WhatsApp (PNG data URL)
// @route   GET /api/whatsapp/qr
// @access  Private
const getQr = async (req, res) => {
  try {
    whatsappService.initialize();
    const info = whatsappService.getStatus();

    if (info.connected) {
      return res.json({
        connected: true,
        status: info.status,
        qr: null,
        message: 'WhatsApp sudah terhubung',
      });
    }

    if (!info.qr) {
      return res.status(202).json({
        connected: false,
        status: info.status,
        qr: null,
        message: 'QR belum tersedia, coba beberapa saat lagi',
      });
    }

    res.json({ connected: false, status: info.status, qr: info.qr });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Putuskan koneksi WhatsApp dan hapus sesi
// @route   POST /api/whatsapp/logout
// @access  Private (admin)
const logout = async (req, res) => {
  try {
    await whatsappService.logout();
    res.json({ message: 'WhatsApp terputus', ...whatsappService.getStatus() });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Mulai ulang koneksi WhatsApp (mis. menampilkan QR baru)
// @route   POST /api/whatsapp/restart
// @access  Private (admin)
const restart = async (req, res) => {
  try {
    whatsappService.restart();
    res.json({
      message: 'Koneksi WhatsApp dimulai ulang',
      ...whatsappService.getStatus(),
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// Simpan nomor pelanggan yang berhasil dikirimi struk agar bisa disarankan
// kembali pada fitur autocomplete. Best-effort: kegagalan menyimpan tidak
// boleh menggagalkan pengiriman struk yang sudah berhasil.
const recordRecipient = async (number) => {
  try {
    if (!number) return;
    await WhatsAppRecipient.findOneAndUpdate(
      { phone: number },
      { lastUsedAt: new Date() },
      { upsert: true }
    );
  } catch (error) {
    console.error('Gagal menyimpan nomor pelanggan:', error.message);
  }
};

// @desc    Cari nomor pelanggan yang pernah dikirimi struk (autocomplete)
// @route   GET /api/whatsapp/recipients?last4=7890&limit=5
// @access  Private
const searchRecipients = async (req, res) => {
  try {
    const digits = String(req.query.last4 || '').replace(/[^0-9]/g, '');
    if (digits.length < 4) {
      return res.json([]);
    }

    const suffix = digits.slice(-4);
    const limit = Math.min(Number(req.query.limit) || 5, 20);

    const recipients = await WhatsAppRecipient.find({
      phone: { $regex: `${suffix}$` },
    })
      .sort({ lastUsedAt: -1 })
      .limit(limit)
      .select('phone lastUsedAt');

    res.json(recipients);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

// @desc    Kirim file PDF struk ke nomor WhatsApp pelanggan
// @route   POST /api/whatsapp/send-document
// @access  Private
// Body (multipart/form-data): file (PDF, field "file"), phone, caption (opsional)
const sendReceiptDocument = async (req, res) => {
  const file = req.file;
  try {
    if (!file) {
      return res
        .status(400)
        .json({ message: 'File PDF struk wajib diunggah pada field "file"' });
    }

    const { phone, caption } = req.body;
    if (!phone || !phone.trim()) {
      return res
        .status(400)
        .json({ message: 'Nomor WhatsApp pelanggan wajib diisi' });
    }

    const filename = /\.pdf$/i.test(file.originalname || '')
      ? file.originalname
      : 'Struk.pdf';

    const result = await whatsappService.sendDocument(phone, file.path, {
      caption,
      filename,
    });

    await recordRecipient(result.number);

    res.json({ message: 'Struk berhasil dikirim ke WhatsApp', ...result });
  } catch (error) {
    res.status(error.statusCode || 500).json({ message: error.message });
  } finally {
    // Hapus file sementara setelah diproses.
    if (file && file.path) {
      fs.promises.unlink(file.path).catch(() => {});
    }
  }
};

module.exports = {
  getPairingPage,
  getStatus,
  getQr,
  searchRecipients,
  recordRecipient,
  sendReceiptDocument,
  logout,
  restart,
};
