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


// controllers/inventoryController.js (or wherever your update route is)
async function updateItemStock(req, res){
  try {
    const { id } = req.params;
    const body = req.body;

    const update = {};
    if ('stock' in body) update.stock = Math.max(0, parseInt(body.stock, 10) || 0);
    if ('unitPrice' in body) update.unitPrice = Number(body.unitPrice) || 0;

    // (optional) accept legacy keys
    if ('qty' in body && !('stock' in body)) {
      update.stock = Math.max(0, parseInt(body.qty, 10) || 0);
    }
    if ('price' in body && !('unitPrice' in body)) {
      update.unitPrice = Number(body.price) || 0;
    }

    const item = await InventoryItem.findByIdAndUpdate(id, update, { new: true });
    if (!item) return res.status(404).json({ message: 'Item not found' });

    res.json({ ok: true, item });
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
};


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



// controllers/inventoryController.js  (approveRequest)
// async function approveRequest(req, res) {
//   try {
//     const { id } = req.params;
//     let { issueQty, note = "", amountDue } = req.body;

//     const r = await IssueRequest.findById(id);
//     if (!r || r.status !== "PENDING") {
//       return res.status(404).json({ ok: false, message: "Request not found or not pending" });
//     }

//     const item = await InventoryItem.findById(r.itemId);
//     if (!item) return res.status(404).json({ ok: false, message: "Item not found" });

//     issueQty = Number(issueQty);
//     if (!Number.isInteger(issueQty) || issueQty <= 0) issueQty = r.qty;

//     if (item.stock < issueQty) {
//       return res.status(400).json({ ok: false, message: "Insufficient stock" });
//     }

//     item.stock -= issueQty;
//     await item.save();

//     // set approval fields
//     r.status       = "APPROVED";
//     r.issuedQty    = issueQty;
//     r.decidedBy    = req.user.userId;
//     r.decidedAt    = new Date();
//     r.decisionNote = note || r.decisionNote;

//     // NEW: expected total price
//     if (amountDue !== undefined && amountDue !== null && !Number.isNaN(Number(amountDue))) {
//       r.amountDue = Number(amountDue);
//     }

//     // compute settlement
//     const rec = r.amountReceived || 0;
//     if (rec <= 0) r.settlementStatus = "DUE";
//     else if (r.amountDue && rec >= r.amountDue) r.settlementStatus = "PAID";
//     else r.settlementStatus = "PARTIAL";

//     await r.save();
//     res.json({ ok: true, request: r, item });
//   } catch (e) {
//     res.status(500).json({ ok: false, message: e.message });
//   }
// }

async function approveRequest(req, res) {
  try {
    const { id } = req.params;  // request id
    const { issuedQty } = req.body;

    const reqDoc = await InventoryRequest.findById(id).populate('item');
    if (!reqDoc) return res.status(404).json({ message: 'Request not found' });
    if (!reqDoc.item) return res.status(400).json({ message: 'Linked item missing' });

    // Freeze price at approval time (source of truth = stock list)
    const unitPrice = Number(reqDoc.item.unitPrice) || 0;
    const qty = Number(issuedQty ?? reqDoc.issuedQty) || 0;

    reqDoc.status = 'APPROVED';
    reqDoc.issuedQty = qty;
    reqDoc.unitPrice = unitPrice;
    reqDoc.totalCost = unitPrice * qty;

    await reqDoc.save();

    // return shaped data used by UI
    const payload = {
      id: reqDoc.id,
      itemName: reqDoc.item.name,
      issuedQty: reqDoc.issuedQty,
      status: reqDoc.status,
      unitPrice: reqDoc.unitPrice,
      totalCost: reqDoc.totalCost,
      amountPaid: reqDoc.amountPaid,
      amountPending: Math.max(0, reqDoc.totalCost - reqDoc.amountPaid),
      requestedDate: reqDoc.createdAt,
    };
    res.json(payload);
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
};
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

// POST /api/inventory/requests/:id/payments
// async function addPaymentProof(req, res) {
//   const { id } = req.params;
//   const { amount, proofUrl, note = "" } = req.body;

//   const r = await IssueRequest.findById(id);
//   if (!r) return res.status(404).json({ ok: false, message: "Request not found" });
//   if (r.status !== "APPROVED") return res.status(400).json({ ok: false, message: "Only approved requests can accept payments" });

//   const amt = Number(amount);
//   if (!Number.isFinite(amt) || amt < 0) return res.status(400).json({ ok: false, message: "amount must be a non-negative number" });
//   if (!proofUrl) return res.status(400).json({ ok: false, message: "proofUrl is required" });

//   r.payments.push({
//     amount: amt,
//     proofUrl,
//     note,
//     uploadedBy: req.user.userId,
//   });

//   r.amountReceived += amt;

//   // update settlement flag
//   if (r.amountDue > 0) {
//     if (r.amountReceived >= r.amountDue) r.settlementStatus = 'PAID';
//     else if (r.amountReceived > 0) r.settlementStatus = 'PARTIAL';
//     else r.settlementStatus = 'DUE';
//   } else {
//     // no due set → consider anything received as PARTIAL unless zero
//     r.settlementStatus = r.amountReceived > 0 ? 'PARTIAL' : 'DUE';
//   }

//   await r.save();
//   res.json({ ok: true, request: r });
// }
async function addPaymentProof(req, res){
  try {
    const { id } = req.params;        // request id
    const { amount } = req.body;      // number
    const reqDoc = await InventoryRequest.findById(id);
    if (!reqDoc) return res.status(404).json({ message: 'Request not found' });

    reqDoc.amountPaid = (reqDoc.amountPaid || 0) + (Number(amount) || 0);
    await reqDoc.save();

    res.json({
      id: reqDoc.id,
      amountPaid: reqDoc.amountPaid,
      amountPending: Math.max(0, (reqDoc.totalCost || 0) - (reqDoc.amountPaid || 0)),
      totalCost: reqDoc.totalCost || 0,
      unitPrice: reqDoc.unitPrice || 0,
    });
  } catch (e) {
    res.status(400).json({ message: e.message });
  }
};


module.exports = {
  listItems,
  seedItems,
  updateItemStock,
  createRequest,
  listRequests,
  approveRequest,
  addPaymentProof,
  rejectRequest,
};
