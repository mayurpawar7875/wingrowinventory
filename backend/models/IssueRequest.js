// backend/models/IssueRequest.js
const mongoose = require("mongoose");
const PaymentProofSchema = new mongoose.Schema({
  amount: { type: Number, required: true, min: 0 },
  proofUrl: { type: String, required: true },
  note: { type: String, default: '' },
  uploadedBy: { type: String, required: true },   // userId
  uploadedAt: { type: Date, default: Date.now },
});
const issueRequestSchema = new mongoose.Schema({
  requestedBy: { type: String, required: true },      // <-- this must exist
  itemId:      { type: mongoose.Schema.Types.ObjectId, ref: "InventoryItem", required: true },
  itemName:    { type: String, required: true },
  qty:         { type: Number, required: true, min: 1 },
  note:        { type: String, default: "" },
  status:      { type: String, enum: ["PENDING","APPROVED","REJECTED"], default: "PENDING" },
  decidedBy:   { type: String },
  decidedAt:   { type: Date },
  status: { type: String, enum: ['PENDING','APPROVED','REJECTED'], default: 'PENDING' },
  issuedQty: { type: Number, default: 0 },

  // NEW: money tracking for issued items
  amountDue:     { type: Number, default: 0 },   // manager's expected total price
  amountReceived:{ type: Number, default: 0 },   // sum of uploaded payments
  settlementStatus: { 
    type: String, 
    enum: ['DUE','PARTIAL','PAID'], 
    default: 'DUE' 
  },
  payments: [{
    amount:    { type: Number, required: true },
    proofUrl:  { type: String, default: '' },
    note:      { type: String, default: '' },
    uploadedAt:{ type: Date, default: Date.now }
  }],

}, { timestamps: true });

module.exports = mongoose.model("IssueRequest", issueRequestSchema);
