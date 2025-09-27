// backend/routes/inventoryRoutes.js
const express = require("express");
const auth = require("../middleware/auth");          // NOTE: default export
const inv = require("../controllers/inventoryController");
const { managerOnly } = require("../middleware/roles");
// const {
//   listItems,
//   seedItems,
//   updateItemStock,
//   createRequest,
//   listRequests,
//   approveRequest,
//   rejectRequest,
// } = require("../controllers/inventoryController");

const router = express.Router();

// ----- Items -----
router.get("/items", auth, inv.listItems);
router.post("/seed", auth, managerOnly, inv.seedItems);
router.patch("/items/:id", auth, managerOnly, inv.updateItemStock);

// ----- Requests -----
router.post("/requests", auth, inv.createRequest);
router.get("/requests", auth, inv.listRequests);
router.post("/requests/:id/approve", auth, managerOnly, inv.approveRequest);
router.post("/requests/:id/reject",  auth, managerOnly, inv.rejectRequest);

module.exports = router;
