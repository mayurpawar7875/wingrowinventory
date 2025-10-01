// server.js (CommonJS)
const express = require("express");
const mongoose = require("mongoose");
const cookieParser = require("cookie-parser");
const cors = require("cors");

// Load .env only in development, NEVER in production on Render
if (process.env.NODE_ENV !== "production") {
  require("dotenv").config();
}

const app = express();

// --- basic middleware
app.use(express.json({ limit: "5mb" }));
app.use(cookieParser());

// For quick testing, allow all origins; tighten later.
app.use(cors({ origin: true, credentials: true }));

// Health
app.get("/health", (req, res) => res.status(200).send("OK"));

// 🔎 Debug the DB name & query (TEMPORARY; remove later)
app.get("/debug/db", (req, res) => {
  const uri = process.env.MONGO_URI || "";
  const db = uri.split("/")[3]?.split("?")[0] || "";
  res.json({
    db,
    hasQuestion: uri.includes("?"),
    sanitized: uri.replace(/\/\/.*?:.*?@/, "//***:***@"),
  });
});

// Routes
const authRoutes = require("./routes/authRoutes");
app.use("/api/auth", authRoutes);
app.use("/api/claims", require("./routes/claimRoutes"));

const path = require("path");
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.use("/api/uploads", require("./routes/uploadRoutes"));
app.use("/api/inventory", require("./routes/inventoryRoutes"));

// Simple root
app.get("/", (req, res) => res.send("Wingrow API running"));

// --- connect to Mongo, then start server
const PORT = process.env.PORT || 4000;
const URI = process.env.MONGO_URI;

if (!URI) {
  console.error("❌ MONGO_URI missing");
  process.exit(1);
}

// Log a safe summary so we can confirm the URI shape in Render logs
console.log(
  "Using Mongo URI:",
  (URI || "").replace(/\/\/.*?:.*?@/, "//***:***@")
);

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
