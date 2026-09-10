const path = require('path');
const QRCode = require('qrcode');
const QRCodeTerminal = require('qrcode-terminal');
const { Client, LocalAuth, MessageMedia } = require('whatsapp-web.js');

// Folder penyimpanan sesi WhatsApp (login tersimpan di sini).
const SESSION_PATH = path.join(__dirname, '..', '..', '.wwebjs_auth');

// Status yang mungkin:
// 'disconnected' | 'initializing' | 'qr' | 'authenticated' | 'connected' | 'auth_failure'
let client = null;
let status = 'disconnected';
let qrDataUrl = null;
let account = null;
let lastError = null;

// Buat instance client beserta event handler-nya.
const buildClient = () => {
  const instance = new Client({
    authStrategy: new LocalAuth({ dataPath: SESSION_PATH }),
    puppeteer: {
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    },
  });

  instance.on('qr', async (qr) => {
    status = 'qr';
    account = null;
    try {
      qrDataUrl = await QRCode.toDataURL(qr, { width: 320, margin: 1 });
    } catch (error) {
      qrDataUrl = null;
      lastError = error.message;
    }
    // Tampilkan QR di terminal agar bisa langsung di-scan.
    console.log('\nWhatsApp: scan QR berikut dari aplikasi WhatsApp > Perangkat Tertaut\n');
    QRCodeTerminal.generate(qr, { small: true });
    const port = process.env.PORT || 3000;
    console.log(
      `Atau buka http://localhost:${port}/api/whatsapp di browser untuk melihat QR.\n`
    );
  });

  instance.on('authenticated', () => {
    status = 'authenticated';
    qrDataUrl = null;
  });

  instance.on('ready', () => {
    status = 'connected';
    qrDataUrl = null;
    lastError = null;
    const info = instance.info;
    account = info
      ? {
          wid: info.wid?._serialized || '',
          number: info.wid?.user || '',
          name: info.pushname || '',
        }
      : null;
    console.log(
      `WhatsApp terhubung${account?.number ? ` sebagai ${account.number}` : ''}.`
    );
  });

  instance.on('auth_failure', (message) => {
    status = 'auth_failure';
    qrDataUrl = null;
    lastError = message || 'Autentikasi gagal';
    console.error('WhatsApp auth gagal:', lastError);
  });

  instance.on('disconnected', (reason) => {
    status = 'disconnected';
    qrDataUrl = null;
    account = null;
    client = null;
    lastError = `Terputus: ${reason}`;
    console.warn('WhatsApp terputus:', reason);
  });

  instance.on('loading_screen', () => {
    if (status !== 'qr') status = 'initializing';
  });

  return instance;
};

// Mulai client WhatsApp (lazy: dipicu oleh endpoint, bukan saat boot server).
const initialize = () => {
  if (client) return client;
  status = 'initializing';
  qrDataUrl = null;
  lastError = null;
  client = buildClient();
  client.initialize().catch((error) => {
    status = 'disconnected';
    lastError = error.message;
    client = null;
    console.error('WhatsApp gagal dijalankan:', error.message);
  });
  return client;
};

// Ringkasan status koneksi untuk endpoint.
const getStatus = () => ({
  status,
  connected: status === 'connected',
  hasQr: Boolean(qrDataUrl),
  qr: qrDataUrl,
  account,
  lastError,
});

// Putuskan koneksi dan hapus sesi agar bisa pairing ulang.
const logout = async () => {
  const current = client;
  client = null;
  status = 'disconnected';
  qrDataUrl = null;
  account = null;
  if (!current) return;
  try {
    await current.logout();
  } catch (error) {
    lastError = error.message;
  }
  try {
    await current.destroy();
  } catch (error) {
    lastError = error.message;
  }
};

// Reset lalu mulai ulang koneksi.
const restart = async () => {
  await logout();
  return initialize();
};

// Normalisasi nomor telepon ke format internasional tanpa "+" (mis. 08xx -> 628xx).
const normalizePhone = (input) => {
  let digits = String(input || '').replace(/[^0-9]/g, '');
  if (!digits) return '';
  if (digits.startsWith('0')) return `62${digits.slice(1)}`;
  if (digits.startsWith('8')) return `62${digits}`;
  return digits;
};

// Apakah koneksi WhatsApp siap dipakai.
const isConnected = () => status === 'connected' && Boolean(client);

// Kirim dokumen (mis. PDF struk) ke nomor WhatsApp pelanggan.
const sendDocument = async (phone, filePath, options = {}) => {
  if (!isConnected()) {
    const error = new Error('WhatsApp belum terhubung. Hubungkan akun terlebih dahulu.');
    error.statusCode = 409;
    throw error;
  }

  const number = normalizePhone(phone);
  if (!number) {
    const error = new Error('Nomor WhatsApp pelanggan tidak valid');
    error.statusCode = 400;
    throw error;
  }

  // Pastikan nomor terdaftar di WhatsApp (fallback ke <nomor>@c.us bila cek gagal).
  let chatId = `${number}@c.us`;
  try {
    const numberId = await client.getNumberId(number);
    if (!numberId) {
      const error = new Error('Nomor WhatsApp tidak terdaftar');
      error.statusCode = 404;
      throw error;
    }
    chatId = numberId._serialized;
  } catch (error) {
    if (error.statusCode) throw error;
  }

  const media = MessageMedia.fromFilePath(filePath);
  if (options.filename) media.filename = options.filename;

  const message = await client.sendMessage(chatId, media, {
    sendMediaAsDocument: true,
    caption: options.caption || '',
  });

  return {
    number,
    chatId,
    messageId: message?.id?._serialized || '',
  };
};

module.exports = {
  initialize,
  getStatus,
  logout,
  restart,
  sendDocument,
  normalizePhone,
};
