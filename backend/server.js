// server.js (CommonJS)
const express = require("express");
const mongoose = require("mongoose");
const cookieParser = require("cookie-parser");
const cors = require("cors");
require("dotenv").config();




const app = express();

// --- basic middleware
app.use(express.json({ limit: "5mb" }));
app.use(cookieParser());
app.use(cors({
  origin: true,        // allow all origins for dev
  credentials: true
}));

const authRoutes = require("./routes/authRoutes");
app.use("/api/auth", authRoutes);

app.use("/api/claims", require("./routes/claimRoutes"));

const path = require("path");
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.use("/api/uploads", require("./routes/uploadRoutes"));
app.use("/api/inventory", require("./routes/inventoryRoutes"));


// --- simple route to see if server is up
app.get("/", (req, res) => res.send("Wingrow API running"));

// --- connect to Mongo, then start server
const PORT = process.env.PORT || 4000;
const URI = process.env.MONGO_URI;

if (!URI) {
  console.error("❌ MONGO_URI missing in .env");
  process.exit(1);
}

mongoose.connect(URI, { autoIndex: true })
  .then(() => {
    console.log("✅ Mongo connected");
    app.listen(PORT, () => console.log("🚀 API on", PORT));
  })
  .catch(err => {
    console.error("❌ Mongo connection error:", err.message);
    process.exit(1);
  });
