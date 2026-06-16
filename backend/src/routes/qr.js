const express = require('express');
const router = express.Router();
const qrController = require('../controllers/qrController');
const { authMiddleware, rbac } = require('../middleware/auth');

router.use(authMiddleware);

router.get('/generate', rbac(['hrd', 'admin']), qrController.generateQR);
router.get('/status', rbac(['hrd', 'admin']), qrController.getStatus);

module.exports = router;
