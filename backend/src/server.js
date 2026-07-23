const fs   = require('fs');
const path = require('path');
const app  = require('./app');
const { startCronJobs } = require('./utils/cronJobs');

const port = process.env.PORT || 3000;

const http = require('http');
const certPath = path.join(__dirname, '..', 'cert.pem');
const keyPath  = path.join(__dirname, '..', 'key.pem');

if (fs.existsSync(certPath) && fs.existsSync(keyPath)) {
  const https = require('https');
  const sslOptions = {
    key:  fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath),
  };

  // HTTPS on port 3443 (for mobile apps)
  const httpsPort = process.env.HTTPS_PORT || 3443;
  https.createServer(sslOptions, app).listen(httpsPort, '0.0.0.0', () => {
    console.log(`🔒 Server (HTTPS) running on https://0.0.0.0:${httpsPort}`);
    console.log(`   → Local:   https://localhost:${httpsPort}`);
    console.log(`   → Network: https://192.168.1.9:${httpsPort}`);
  });

  // HTTP on port 3000 (for Flutter web / browser)
  http.createServer(app).listen(port, '0.0.0.0', () => {
    console.log(`🌐 Server (HTTP)  running on http://0.0.0.0:${port}`);
    console.log(`   → Local:   http://localhost:${port}`);
    console.log(`   → Network: http://192.168.1.9:${port}`);
    startCronJobs();
  });
} else {
  // Fallback HTTP only (development tanpa sertifikat)
  http.createServer(app).listen(port, '0.0.0.0', () => {
    console.log(`Server (HTTP) running on http://0.0.0.0:${port}`);
    console.log(`   → Local:   http://localhost:${port}`);
    console.log(`   → Network: http://192.168.1.9:${port}`);
    startCronJobs();
  });
}
