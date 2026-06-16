/**
 * HTTPS Static file server untuk akses Flutter Web dari HP.
 * Serve folder build/web di port 4443, bind ke 0.0.0.0.
 *
 * Prasyarat: jalankan sekali di laptop:
 *   mkcert -install
 *   (sertifikat cert.pem + key.pem sudah dibuat otomatis)
 *
 * Lalu install rootCA di HP — lihat instruksi di README.
 *
 * Usage: node serve_mobile_https.cjs
 */
const https = require('https');
const fs    = require('fs');
const path  = require('path');

const PORT     = 4443;
const BUILD_DIR = path.join(__dirname, 'build', 'web');
const CERT_FILE = path.join(__dirname, 'cert.pem');
const KEY_FILE  = path.join(__dirname, 'key.pem');

// Validasi file sertifikat ada
if (!fs.existsSync(CERT_FILE) || !fs.existsSync(KEY_FILE)) {
  console.error('❌  cert.pem / key.pem tidak ditemukan!');
  console.error('   Jalankan dulu:');
  console.error('   mkcert -key-file key.pem -cert-file cert.pem 192.168.1.9 localhost 127.0.0.1');
  process.exit(1);
}

const MIME_TYPES = {
  '.html': 'text/html',
  '.js':   'application/javascript',
  '.css':  'text/css',
  '.json': 'application/json',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.svg':  'image/svg+xml',
  '.ico':  'image/x-icon',
  '.woff': 'font/woff',
  '.woff2':'font/woff2',
  '.ttf':  'font/ttf',
  '.wasm': 'application/wasm',
};

const sslOptions = {
  key:  fs.readFileSync(KEY_FILE),
  cert: fs.readFileSync(CERT_FILE),
};

const server = https.createServer(sslOptions, (req, res) => {
  let filePath = path.join(BUILD_DIR, req.url === '/' ? 'index.html' : req.url);

  // SPA fallback
  if (!fs.existsSync(filePath)) {
    filePath = path.join(BUILD_DIR, 'index.html');
  }

  const ext         = path.extname(filePath).toLowerCase();
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end('Not Found');
      return;
    }
    res.writeHead(200, { 'Content-Type': contentType });
    res.end(data);
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('\n🔒 HTTPS Mobile Server berjalan!');
  console.log(`   Local:   https://localhost:${PORT}`);
  console.log(`   Network: https://192.168.1.9:${PORT}`);
  console.log('\n   Buka URL "Network" di browser HP kamu.');
  console.log('   ⚠️  Pastikan rootCA sudah diinstall di HP (lihat instruksi).\n');
});
