const express = require('express');
const router  = express.Router();
const userController = require('../controllers/userController');
const { authMiddleware, rbac } = require('../middleware/auth');
const { validate, validateUUID, updateUserSchema } = require('../middleware/validate');

router.use(authMiddleware);

router.get('/',       rbac(['admin', 'hrd']),  userController.getAllUsers);
router.put('/:id',    rbac(['admin']), validateUUID('id'), validate(updateUserSchema), userController.updateUser);
router.delete('/:id', rbac(['admin']), validateUUID('id'), userController.deactivateUser);

module.exports = router;
