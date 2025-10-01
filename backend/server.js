// server.js (CommonJS)
const express = require("express");
const mongoose = require("mongoose");
const cookieParser = require("cookie-parser");
const cors = require("cors");
const path = require("path");

// Load .env only in development (Render sets env vars itself)
if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}

const app = express();

// ---------- Middleware ----------
app.use(express.json({ limit: "5mb" }));
app.use(cookieParser());

// For quick testing: allow any origin. Tighten this later.
app.use(cors({ origin: true, credentials: true }));

// ---------- Health & Debug ----------
app.get("/health", (req, res) => res.status(200).send("OK"));

// TEMP debug to verify DB name and URI shape (remove later)
app.get("/debug/db", (req, res) => {
  const uri = process.env.MONGO_URI || "";
  const db = uri.split("/")[3]?.split("?")[0] || "";
  res.json({
    db,
    hasQuestion: uri.includes("?"),
    sanitized: uri.replace(/\/\/.*?:.*?@/, "//***:***@"),
  });
});

// ---------- Routes ----------
app.use("/api/auth", require("./routes/authRoutes"));
app.use("/api/claims", require("./routes/claimRoutes"));
app.use("/api/uploads", require("./routes/uploadRoutes"));
app.use("/api/inventory", require("./routes/inventoryRoutes"));
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// Simple root
app.get("/", (req, res) => res.send("Wingrow API running"));

// ---------- TEMP: seed superadmin (REMOVE AFTER USE) ----------
const bcrypt = require("bcryptjs");
app.post("/dev/seed-superadmin", async (req, res) => {
  try {
    if (req.query.key !== process.env.SEED_KEY) {
      return res.status(403).send("nope");
    }
    // Adjust the model path/name if needed
    const Users = require("./models/User");

    const hash = bcrypt.hashSync("Wingrow@1234", 10);
    await Users.updateOne(
      { userId: "superadmin" },
      { $set: { password: hash, role: "manager" } },
      { upsert: true }
    );

    res.send("superadmin seeded");
  } catch (e) {
    console.error("Seed error:", e);
    res.status(500).send("seed failed");
  }
});
// --------------------------------------------------------------

// ---------- Mongo connect & start ----------
const PORT = process.env.PORT || 4000;
const URI = process.env.MONGO_URI;

if (!URI) {
  console.error("❌ MONGO_URI missing");
  process.exit(1);
}

// Safe log (won't print credentials or query)
console.log("Using Mongo URI:", (URI || "").replace(/\/\/.*?:.*?@/, "//***:***@"));

mongoose
  .connect(URI, { autoIndex: true })
  .then(() => {
    console.log("✅ Mongo connected");
    app.listen(PORT, () => console.log("🚀 API on", PORT));
  })
  .catch((err) => {
    console.error("❌ Mongo connection error:", err.message);
    process.exit(1);
  });
