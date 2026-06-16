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

router.post('/tenants',     superadminController.createTenant);
router.get('/tenants',      superadminController.getTenants);
router.put('/tenants/:id',  superadminController.updateTenantPlan);
router.get('/analytics',    superadminController.getTenantAnalytics);

module.exports = router;
