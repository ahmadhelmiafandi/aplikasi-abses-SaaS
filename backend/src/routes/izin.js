const express = require('express');
const router  = express.Router();
const izinController = require('../controllers/izinController');
const { authMiddleware, rbac } = require('../middleware/auth');
const { validate, validateUUID, applyIzinSchema, reviewIzinSchema } = require('../middleware/validate');

router.use(authMiddleware);

router.post('/ajukan',      rbac(['karyawan', 'admin', 'hrd', 'manajer']), validate(applyIzinSchema),  izinController.applyIzin);
router.get('/saya',         rbac(['karyawan', 'admin', 'hrd', 'manajer']),                              izinController.getMyIzin);
router.get('/pending',      rbac(['manajer', 'hrd']),                                                   izinController.getPendingIzin);
router.put('/:id/review',   rbac(['manajer', 'hrd']), validateUUID('id'), validate(reviewIzinSchema),  izinController.reviewIzin);

module.exports = router;
