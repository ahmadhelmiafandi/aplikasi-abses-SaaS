const express    = require('express');
const cors       = require('cors');
const morgan     = require('morgan');
const path       = require('path');
const helmet     = require('helmet');
const rateLimit  = require('express-rate-limit');
const Sentry     = require('@sentry/node');
const { v4: uuidv4 } = require('crypto'); // built-in Node.js crypto, no extra package
require('dotenv').config();

// ── Sentry Error Tracking ─────────────────────────────────────────────────────
if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV || 'development',
    tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.2 : 1.0,
    // Attach request data for better debugging
    integrations: [
      Sentry.httpIntegration(),
    ],
  });
}

const logger       = require('./config/logger');
const authRoutes   = require('./routes/auth');
const absensiRoutes = require('./routes/absensi');
const izinRoutes   = require('./routes/izin');
const laporanRoutes = require('./routes/laporan');
const qrRoutes     = require('./routes/qr');
const usersRoutes  = require('./routes/users');
const profileRoutes = require('./routes/profile');

const app = express();

// ── Request ID ────────────────────────────────────────────────────────────────
app.use((req, res, next) => {
  req.id = req.headers['x-request-id'] || require('crypto').randomUUID();
  res.setHeader('X-Request-ID', req.id);
  next();
});

// ── Security headers ─────────────────────────────────────────────────────────
app.use(helmet({
  frameguard:           process.env.NODE_ENV === 'production' ? { action: 'deny' } : false,
  contentSecurityPolicy: process.env.NODE_ENV === 'production',
}));

// ── CORS ──────────────────────────────────────────────────────────────────────
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((s) => s.trim())
  : ['http://localhost:3000', 'http://localhost:4000'];

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (
      allowedOrigins.includes(origin) ||
      /^http:\/\/localhost(:\d+)?$/.test(origin) ||
      /^http:\/\/127\.0\.0\.1(:\d+)?$/.test(origin) ||
      /^http:\/\/192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$/.test(origin)
    ) {
      return callback(null, true);
    }
    callback(new Error(`CORS: Origin ${origin} tidak diizinkan`));
  },
  credentials: true,
}));

// ── Rate limiting ─────────────────────────────────────────────────────────────
app.use(rateLimit({
  windowMs: 60_000,
  max:      200,
  standardHeaders: true,
  legacyHeaders:   false,
}));

const absensiLimiter = rateLimit({
  windowMs: 10_000,
  max:      5,
  message:  { success: false, message: 'Terlalu banyak request. Tunggu sebentar.' },
});
app.use('/api/absensi/checkin',  absensiLimiter);
app.use('/api/absensi/checkout', absensiLimiter);

// ── Logging & body parser ─────────────────────────────────────────────────────
// Morgan → Winston stream
app.use(morgan('combined', {
  stream: { write: (msg) => logger.http(msg.trim()) },
}));
app.use(express.json({ limit: '1mb' }));
// ── Routes (/api/v1 + backward compat /api) ───────────────────────────────────
const tenantResolver = require('./middleware/tenant');
const v1Router = express.Router();
v1Router.use(tenantResolver);
v1Router.use('/auth',    authRoutes);
v1Router.use('/absensi', absensiRoutes);
v1Router.use('/izin',    izinRoutes);
v1Router.use('/laporan', laporanRoutes);
v1Router.use('/qr',      qrRoutes);
v1Router.use('/users',   usersRoutes);
v1Router.use('/profile', profileRoutes);

const superadminRoutes = require('./routes/superadmin');
app.use('/superadmin', superadminRoutes);
app.use('/api/v1', v1Router);
app.use('/api',    v1Router);
// ── X-API-Version header ──────────────────────────────────────────────────────
app.use((req, res, next) => {
  res.setHeader('X-API-Version', '1.0');
  next();
});

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', async (req, res) => {
  const supabase = require('./config/supabase');
  let dbStatus   = 'ok';

  try {
    const { error } = await supabase.from('profiles').select('id').limit(1);
    if (error) dbStatus = 'error';
  } catch {
    dbStatus = 'error';
  }

  const status = dbStatus === 'ok' ? 200 : 503;
  res.status(status).json({
    status:    dbStatus === 'ok' ? 'ok' : 'degraded',
    timestamp: new Date().toISOString(),
    version:   process.env.npm_package_version || '1.0.0',
    uptime:    process.uptime(),
    services:  { supabase: dbStatus },
  });
});

// ── API Documentation (Swagger UI) ───────────────────────────────────────────
app.use('/api-docs', (req, res, next) => {
  res.setHeader("Content-Security-Policy", "default-src * 'unsafe-inline' 'unsafe-eval'; script-src * 'unsafe-inline' 'unsafe-eval'; style-src * 'unsafe-inline';");
  next();
});

app.get('/swagger.yaml', (req, res) => {
  res.sendFile(path.join(__dirname, 'docs', 'swagger.yaml'));
});

app.get('/api-docs', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>SiAbsen API Documentation</title>
      <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
      <style>
        html { box-sizing: border-box; overflow: -y-scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin:0; background: #fafafa; }
      </style>
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
      <script>
        window.onload = function() {
          window.ui = SwaggerUIBundle({
            url: "/swagger.yaml",
            dom_id: '#swagger-ui',
            deepLinking: true,
            presets: [
              SwaggerUIBundle.presets.apis,
            ],
            layout: "BaseLayout"
          });
        };
      </script>
    </body>
    </html>
  `);
});

app.get('/', (req, res) => res.json({
  message: 'SiAbsen API — powered by Supabase',
  docs:    '/api-docs',
}));

// ── Sentry error handler (must be before global error handler) ────────────────
if (process.env.SENTRY_DSN) {
  Sentry.setupExpressErrorHandler(app);
}

// ── Global error handler ──────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  logger.error({ message: err.message, stack: err.stack, requestId: req.id });
  res.status(500).json({ success: false, message: 'Internal Server Error' });
});

module.exports = app;
