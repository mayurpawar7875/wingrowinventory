// backend/models/IssueRequest.js
const mongoose = require("mongoose");

const issueRequestSchema = new mongoose.Schema({
  requestedBy: { type: String, required: true },      // <-- this must exist
  itemId:      { type: mongoose.Schema.Types.ObjectId, ref: "InventoryItem", required: true },
  itemName:    { type: String, required: true },
  qty:         { type: Number, required: true, min: 1 },
  note:        { type: String, default: "" },
  status:      { type: String, enum: ["PENDING","APPROVED","REJECTED"], default: "PENDING" },
  decidedBy:   { type: String },
  decidedAt:   { type: Date },
}, { timestamps: true });

module.exports = mongoose.model("IssueRequest", issueRequestSchema);
