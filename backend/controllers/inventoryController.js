// controllers/inventoryController.js
const InventoryItem = require("../models/InventoryItem");
const IssueRequest  = require("../models/IssueRequest");

// ---------- ITEMS ----------

// GET /api/inventory/items
async function listItems(_req, res) {
  try {
    const items = await InventoryItem.find().sort({ name: 1 });
    res.json({ ok: true, items });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
}

// POST /api/inventory/seed  (manager)
async function seedItems(_req, res) {
  try {
    const names = [
      "Apron","Cap","Flex","Tent Cloths","Table","Tent Structure",
      "Small Rate Board","Jacket","Big Rate Board","Diary","Marker",
    ];
    const ops = names.map(n => ({
      updateOne: {
        filter: { name: n },
        update: { $setOnInsert: { name: n, unit: "pcs", stock: 20 } },
        upsert: true,
      }
    }));
    await InventoryItem.bulkWrite(ops);
    const items = await InventoryItem.find().sort({ name: 1 });
    res.json({ ok: true, items });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
}

/**
 * PATCH /api/inventory/items/:id
 * body: { stock: <non-negative integer> }
 * (manager)
 */
// async function updateItemStock(req, res) {
//   try {
//     const { id } = req.params;
//     let { stock } = req.body;

//     if (typeof stock === "string") stock = stock.trim();
//     const n = Number(stock);
//     if (!Number.isInteger(n) || n < 0) {
//       return res.status(400).json({ ok: false, message: "stock must be a non-negative integer" });
//     }

//     const item = await InventoryItem.findById(id);
//     if (!item) return res.status(404).json({ ok: false, message: "Item not found" });

//     item.stock = n;
//     await item.save();
//     res.json({ ok: true, item });
//   } catch (e) {
//     res.status(500).json({ ok: false, message: e.message });
//   }
// }

async function updateItemStock(req, res) {
  try {
    const { id } = req.params;
    let { stock } = req.body;

    // ✅ Ensure it is a number
    const n = parseInt(stock, 10);
    if (isNaN(n) || n < 0) {
      return res
        .status(400)
        .json({ ok: false, message: "stock must be a non-negative integer" });
    }

    const item = await InventoryItem.findById(id);
    if (!item)
      return res.status(404).json({ ok: false, message: "Item not found" });

    item.stock = n;
    await item.save();
    res.json({ ok: true, item });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
}

// ---------- ISSUE REQUESTS ----------

// POST /api/inventory/requests  (organizer)
async function createRequest(req, res) {
  try {
    const { itemId, qty, note = "" } = req.body;
    const n = Number(qty);
    if (!itemId || !Number.isInteger(n) || n <= 0) {
      return res.status(400).json({ ok: false, message: "itemId and positive integer qty required" });
    }

    const item = await InventoryItem.findById(itemId);
    if (!item) return res.status(404).json({ ok: false, message: "Item not found" });

    const me = req.user.userId;

    const r = await IssueRequest.create({
      userId: me,               // preferred
      requestedBy: me,          // backward compatibility with older schema/data
      itemId: item._id,
      itemName: item.name,
      qty: n,
      note,
    });

    res.json({ ok: true, request: r });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
}

// GET /api/inventory/requests?mine=true|false&status=PENDING|APPROVED|REJECTED
async function listRequests(req, res) {
  try {
    const { mine, status } = req.query;
    const filter = {};

    // Non-managers may only see their own; mine=true also restricts
    if (mine === "true" || req.user.role !== "manager") {
      const me = req.user.userId;
      filter.$or = [{ userId: me }, { requestedBy: me }];
    }

    if (status && ["PENDING","APPROVED","REJECTED"].includes(status)) {
      filter.status = status;
    }

    const requests = await IssueRequest.find(filter).sort({ createdAt: -1 });
    res.json({ ok: true, requests });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
}

// POST /api/inventory/requests/:id/approve  (manager)
async function approveRequest(req, res) {
  try {
    const { id } = req.params;
    let { issueQty, note = "" } = req.body;

    const r = await IssueRequest.findById(id);
    if (!r || r.status !== "PENDING") {
      return res.status(404).json({ ok: false, message: "Request not found or not pending" });
    }

    const item = await InventoryItem.findById(r.itemId);
    if (!item) return res.status(404).json({ ok: false, message: "Item not found" });

    issueQty = Number(issueQty);
    if (!Number.isInteger(issueQty) || issueQty <= 0) issueQty = r.qty;

    if (item.stock < issueQty) {
      return res.status(400).json({ ok: false, message: "Insufficient stock" });
    }

    // deduct and save
    item.stock -= issueQty;
    await item.save();

    // mark approved
    r.status       = "APPROVED";
    r.issuedQty    = issueQty;
    r.decidedBy    = req.user.userId;
    r.decidedAt    = new Date();
    r.decisionNote = note || r.decisionNote;
    await r.save();

    res.json({ ok: true, request: r, item });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
}

// POST /api/inventory/requests/:id/reject  (manager)
async function rejectRequest(req, res) {
  try {
    const { id } = req.params;
    const { note = "" } = req.body;

    const r = await IssueRequest.findById(id);
    if (!r || r.status !== "PENDING") {
      return res.status(404).json({ ok: false, message: "Request not found or not pending" });
    }

    r.status       = "REJECTED";
    r.decidedBy    = req.user.userId;
    r.decidedAt    = new Date();
    r.decisionNote = note || r.decisionNote;
    await r.save();

    res.json({ ok: true, request: r });
  } catch (e) {
    res.status(500).json({ ok: false, message: e.message });
  }
}

module.exports = {
  listItems,
  seedItems,
  updateItemStock,
  createRequest,
  listRequests,
  approveRequest,
  rejectRequest,
};
