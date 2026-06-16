const express = require('express');
const router  = express.Router();
const profileController = require('../controllers/profileController');
const { authMiddleware } = require('../middleware/auth');
const { validate, updateProfileSchema } = require('../middleware/validate');

router.use(authMiddleware);

router.get('/',                profileController.getProfile);
router.put('/', validate(updateProfileSchema), profileController.updateProfile);
router.put('/change-password', profileController.changePassword);

module.exports = router;
