// backend/routes/claimRoutes.js
const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");              // MUST be a function
const c = require("../controllers/claimController");     // object with fn props
const { managerOnly } = require('../middleware/roles');
const {
  listApprovals,
  listClaims
 // other claim handlers...
} = require('../controllers/claimController');


// ---- Manager-specific routes first (avoid "/:id" catching them) ----
router.get("/approvals/pending", auth, c.pendingApprovals);
router.get("/approvals", auth, c.approvalsByStatus);
router.post("/:id/approve", auth, c.approve);
router.post("/:id/reject", auth, c.reject);
router.post("/:id/mark-paid", auth, c.markPaid);
router.get('/approvals', auth, managerOnly, listApprovals);

// ---- Organizer routes ----
router.post("/", auth, c.createOrGetDraft);
router.post("/:id/items", auth, c.addItem);
router.delete("/:id/items/:idx", auth, c.deleteItem);
router.post("/:id/submit", auth, c.submit);
router.get('/', auth, listClaims);

// ---- Common ----
// router.get("/", auth, c.list);
router.get("/:id", auth, c.getOne);

module.exports = router;
