// backend/controllers/claimController.js
const Claim = require("../models/Claim");

function recalcTotal(claim) {
  claim.totalAmount = (claim.items || []).reduce(
    (s, it) => s + (Number(it.amount) || 0),
    0
  );
}

// organizer
async function createOrGetDraft(req, res) {
  const uid = req.user.userId;
  let claim = await Claim.findOne({ userId: uid, status: "DRAFT" });
  if (!claim) claim = await Claim.create({ userId: uid });
  return res.json({ ok: true, claimId: claim._id });
}

async function addItem(req, res) {
  const uid = req.user.userId;
  const { id } = req.params;
  let { date, category = "Other", amount, notes = "", receiptUrl = "" } = req.body;

  const amt = Number(amount);
  if (!date || Number.isNaN(amt) || amt <= 0) {
    return res.status(400).json({ message: "Valid date and amount required" });
  }
  const parsedDate = new Date(date);
  if (isNaN(parsedDate.getTime())) {
    return res.status(400).json({ message: "Invalid date" });
  }

  const claim = await Claim.findOne({ _id: id, userId: uid, status: "DRAFT" });
  if (!claim) return res.status(404).json({ message: "Draft claim not found" });

  claim.items.push({ date: parsedDate, category, amount: amt, notes, receiptUrl });
  recalcTotal(claim);
  await claim.save();
  return res.json({ ok: true, items: claim.items, totalAmount: claim.totalAmount });
}

async function deleteItem(req, res) {
  const uid = req.user.userId;
  const { id, idx } = req.params;
  const claim = await Claim.findOne({ _id: id, userId: uid, status: "DRAFT" });
  if (!claim) return res.status(404).json({ message: "Draft claim not found" });

  const i = Number(idx);
  if (Number.isNaN(i) || i < 0 || i >= claim.items.length) {
    return res.status(400).json({ message: "Invalid item index" });
  }
  claim.items.splice(i, 1);
  recalcTotal(claim);
  await claim.save();
  return res.json({ ok: true, items: claim.items, totalAmount: claim.totalAmount });
}

async function submit(req, res) {
  const uid = req.user.userId;
  const { id } = req.params;
  const claim = await Claim.findOne({ _id: id, userId: uid, status: "DRAFT" });
  if (!claim) return res.status(404).json({ message: "Draft claim not found" });
  if (claim.items.length === 0) return res.status(400).json({ message: "No items to submit" });

  recalcTotal(claim);
  claim.status = "SUBMITTED";
  await claim.save();
  return res.json({ ok: true });
}

// common
async function list(req, res) {
  const mine = req.query.mine === "true";
  const filter = mine ? { userId: req.user.userId } : {};
  const claims = await Claim.find(filter).sort({ createdAt: -1 });
  return res.json({ ok: true, claims });
}

async function getOne(req, res) {
  const c = await Claim.findById(req.params.id);
  if (!c) return res.status(404).json({ message: "Not found" });
  if (req.user.role !== "manager" && c.userId !== req.user.userId) {
    return res.status(403).json({ message: "Forbidden" });
  }
  return res.json({ ok: true, claim: c });
}

// manager
async function pendingApprovals(_req, res) {
  const claims = await Claim.find({ status: "SUBMITTED" }).sort({ createdAt: 1 });
  return res.json({ ok: true, claims });
}

async function approvalsByStatus(req, res) {
  if (req.user.role !== "manager") return res.status(403).json({ message: "Forbidden" });
  const status = ["SUBMITTED", "APPROVED"].includes(req.query.status)
    ? req.query.status
    : "SUBMITTED";
  const claims = await Claim.find({ status }).sort({ createdAt: 1 });
  return res.json({ ok: true, claims });
}

async function approve(req, res) {
  if (req.user.role !== "manager") return res.status(403).json({ message: "Forbidden" });
  const c = await Claim.findById(req.params.id);
  if (!c || c.status !== "SUBMITTED") return res.status(400).json({ message: "Not in SUBMITTED state" });
  c.status = "APPROVED";
  c.approvedBy = req.user.userId;
  c.approvedAt = new Date();
  c.managerComment = (req.body?.comment || "").toString();
  await c.save();
  return res.json({ ok: true });
}

async function reject(req, res) {
  if (req.user.role !== "manager") return res.status(403).json({ message: "Forbidden" });
  const c = await Claim.findById(req.params.id);
  if (!c || c.status !== "SUBMITTED") return res.status(400).json({ message: "Not in SUBMITTED state" });
  c.status = "REJECTED";
  c.approvedBy = req.user.userId;
  c.approvedAt = new Date();
  c.managerComment = (req.body?.comment || "").toString();
  await c.save();
  return res.json({ ok: true });
}

async function markPaid(req, res) {
  if (req.user.role !== "manager") return res.status(403).json({ message: "Forbidden" });
  const c = await Claim.findById(req.params.id);
  if (!c) return res.status(404).json({ message: "Not found" });
  if (c.status !== "APPROVED") return res.status(400).json({ message: "Only APPROVED can be marked PAID" });
  c.status = "PAID";
  c.paidAt = new Date();
  c.paymentRef = (req.body?.paymentRef || "").toString();
  await c.save();
  return res.json({ ok: true });
}

// GET /api/claims/approvals?status=SUBMITTED|APPROVED|REJECTED
async function approvalsByStatus(req, res) {
  const status = (req.query.status || "SUBMITTED").toUpperCase();
  const allowed = ["SUBMITTED", "APPROVED", "REJECTED"];
  if (!allowed.includes(status)) {
    return res.status(400).json({ message: "Invalid status" });
  }
  const claims = await Claim.find({ status }).sort({ createdAt: -1 });
  res.json({ ok: true, claims });
}

module.exports = {
  createOrGetDraft,
  addItem,
  deleteItem,
  submit,
  list,
  getOne,
  pendingApprovals,
  approvalsByStatus,
  approve,
  reject,
  markPaid,
};

