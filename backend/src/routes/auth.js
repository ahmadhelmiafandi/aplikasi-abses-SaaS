/**
 * Auth routes — minimal.
 * Login & register ditangani Supabase Auth SDK di client Flutter.
 * Endpoint ini hanya menerima request lama agar tidak 404.
 */const express = require('express');
const router  = express.Router();
const authController = require('../controllers/authController');
const { karyawanLimitGuard } = require('../middleware/planGuard');

router.post('/login',    authController.login);
router.post('/register', karyawanLimitGuard, authController.register);
router.post('/refresh',  authController.refresh);

module.exports = router;
