const express = require('express');
const router = express.Router();
const laporanController = require('../controllers/laporanController');
const { authMiddleware, rbac } = require('../middleware/auth');

router.use(authMiddleware);
router.use(rbac(['hrd', 'admin', 'manajer']));

router.get('/bulanan',      laporanController.getMonthlyReport);
router.get('/export/excel', laporanController.exportExcel);
router.get('/export/pdf',   laporanController.exportPdf);

module.exports = router;
