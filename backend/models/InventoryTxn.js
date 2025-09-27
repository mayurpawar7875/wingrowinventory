const mongoose = require("mongoose");
const { Schema } = mongoose;

const InventoryTxnSchema = new Schema(
  {
    itemId: { type: Schema.Types.ObjectId, ref: "InventoryItem", required: true },
    userId: { type: String, required: true }, // who receives/returns
    type: { type: String, enum: ["ISSUE", "RETURN"], required: true },
    qty: { type: Number, required: true },
    refId: { type: String, default: "" },     // request id
  },
  { timestamps: true }
);

module.exports = mongoose.model("InventoryTxn", InventoryTxnSchema);
