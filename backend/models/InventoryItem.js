const mongoose = require("mongoose");

const InventoryItemSchema = new mongoose.Schema(
  {
    name: { type: String, required: true },
    sku: { type: String, default: "" },
    unit: { type: String, default: "pcs" },
    stock: { type: Number, default: 0 }, // available stock
    unitPrice: { type: Number, default: 0 },   // <— NEW
    totalCost: { type: Number, default: 0 },               // issuedQty * unitPriceAtApproval
    amountPaid: { type: Number, default: 0 },  
    
  },
  { timestamps: true }
);

module.exports = mongoose.model("InventoryItem", InventoryItemSchema);
