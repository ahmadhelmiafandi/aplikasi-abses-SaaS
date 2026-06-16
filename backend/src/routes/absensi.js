const express  = require('express');
const router   = express.Router();
const absensiController = require('../controllers/absensiController');
const { authMiddleware, rbac } = require('../middleware/auth');
const { validate, validateUUID, checkInSchema, scanQrSchema } = require('../middleware/validate');

router.use(authMiddleware);

const allRoles = rbac(['karyawan', 'admin', 'hrd', 'manajer']);

router.post('/checkin',  allRoles, validate(checkInSchema),  absensiController.checkIn);
router.post('/checkout', allRoles,                            absensiController.checkOut);
router.post('/scan-qr',  allRoles, validate(scanQrSchema),   absensiController.scanQR);
router.get('/riwayat',   allRoles,                            absensiController.getHistory);
router.get('/hari-ini',  allRoles,                            absensiController.getTodayStatus);

module.exports = router;
