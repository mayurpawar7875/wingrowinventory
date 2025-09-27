// const mongoose = require("mongoose");

// const itemSchema = new mongoose.Schema({
//   date: { type: Date, required: true },
//   category: { type: String, enum: ["Travel","Food","Supplies","Other"], default: "Other" },
//   amount: { type: Number, required: true },
//   notes: { type: String, default: "" },
//   receiptUrl: { type: String, default: "" } // optional
// }, { _id: false });

// const claimSchema = new mongoose.Schema({
//   userId: { type: String, required: true },               // matches auth userId
//   status: { type: String, enum: ["DRAFT","SUBMITTED","APPROVED","REJECTED","PAID"], default: "DRAFT" },
//   items: [itemSchema],
// }, { timestamps: true });

// module.exports = mongoose.model("Claim", claimSchema);


const mongoose = require("mongoose");

const itemSchema = new mongoose.Schema(
  {
    date: { type: Date, required: true },
    category: { type: String, default: "Other" },
    amount: { type: Number, required: true },
    notes: { type: String, default: "" },
    receiptUrl: { type: String, default: "" },
  },
  { _id: false }
);

const claimSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true }, // organizer's userId
    status: {
      type: String,
      enum: ["DRAFT", "SUBMITTED", "APPROVED", "REJECTED", "PAID"],
      default: "DRAFT",
    },
    items: { type: [itemSchema], default: [] },

    // NEW: denormalized total & payment info
    totalAmount: { type: Number, default: 0 },
    paidAt: { type: Date },
    paymentRef: { type: String, default: "" },

    // optional approver tracking if you want (already used earlier)
    approvedBy: { type: String, default: "" },
    approvedAt: { type: Date },
    managerComment: { type: String, default: "" },
  },
  { timestamps: true }
);

module.exports = mongoose.model("Claim", claimSchema);

