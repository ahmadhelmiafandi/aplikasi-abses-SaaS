const express = require('express');
const router  = express.Router();
const superadminController = require('../controllers/superadminController');
const { errorResponse } = require('../utils/response');

/**
 * Guard sederhana untuk melindungi portal super admin menggunakan API key.
 */
const superAdminGuard = (req, res, next) => {
  const adminKey = req.headers['x-super-admin-key'];
  const expectedKey = process.env.SUPER_ADMIN_KEY || 'SuperAdminSecretKey';
  
  if (!adminKey || adminKey !== expectedKey) {
    return errorResponse(res, 'Forbidden: Akses Super Admin ditolak', 403);
  }
  next();
};

router.use(superAdminGuard);

// ── Tenants ──────────────────────────────────────────────────────────────────
router.post('/tenants',     superadminController.createTenant);
router.get('/tenants',      superadminController.getTenants);
router.put('/tenants/:id',  superadminController.updateTenantPlan);
router.delete('/tenants/:id', superadminController.deleteTenant);
router.get('/analytics',    superadminController.getTenantAnalytics);

// ── Plans ─────────────────────────────────────────────────────────────────────
router.get('/plans',        superadminController.getPlans);
router.post('/plans',       superadminController.createPlan);
router.put('/plans/:id',    superadminController.updatePlan);
router.delete('/plans/:id', superadminController.deletePlan);

// ── Users ─────────────────────────────────────────────────────────────────────
router.get('/users',        superadminController.getUsers);
router.post('/users',       superadminController.createUser);
router.put('/users/:id',    superadminController.updateUser);
router.delete('/users/:id', superadminController.deleteUser);

// ── Attendance ────────────────────────────────────────────────────────────────
router.get('/absensi',      superadminController.getAbsensi);
router.put('/absensi/:id',  superadminController.updateAbsensi);
router.delete('/absensi/:id', superadminController.deleteAbsensi);

// ── Leave Requests ────────────────────────────────────────────────────────────
router.get('/izin',         superadminController.getIzin);
router.put('/izin/:id',     superadminController.updateIzin);
router.delete('/izin/:id',  superadminController.deleteIzin);

module.exports = router;
