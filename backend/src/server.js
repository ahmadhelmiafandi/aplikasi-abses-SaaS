const fs   = require('fs');
const path = require('path');
const app  = require('./app');
const { startCronJobs } = require('./utils/cronJobs');

const port = process.env.PORT || 3000;

// ── HTTPS jika sertifikat tersedia, HTTP jika tidak ───────────────────────────
const certPath = path.join(__dirname, '..', 'cert.pem');
const keyPath  = path.join(__dirname, '..', 'key.pem');

if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
  const https = require('https');
  const sslOptions = {
    key:  fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath),
  };

  https.createServer(sslOptions, app).listen(port, '0.0.0.0', () => {
    console.log(`🔒 Server (HTTPS) running on https://0.0.0.0:${port}`);
    console.log(`   → Local:   https://localhost:${port}`);
    console.log(`   → Network: https://192.168.1.9:${port}`);
    startCronJobs();
  });
} else {
  // Fallback HTTP (development tanpa sertifikat)
  app.listen(port, '0.0.0.0', () => {
    console.log(`Server (HTTP) running on http://0.0.0.0:${port}`);
    console.log(`   → Local:   http://localhost:${port}`);
    console.log(`   → Network: http://192.168.1.9:${port}`);
    startCronJobs();
  });
}
