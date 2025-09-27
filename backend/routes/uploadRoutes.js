// backend/routes/uploadRoutes.js
const path = require("path");
const fs = require("fs");
const express = require("express");
const multer = require("multer");
const auth = require("../middleware/auth"); // <-- default export, not destructured

const router = express.Router();

// ensure uploads dir exists
const dir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });

// store locally as <timestamp>_<originalname>
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, dir),
  filename: (_req, file, cb) =>
    cb(null, Date.now() + "_" + file.originalname.replace(/\s+/g, "_")),
});

const upload = multer({ storage });

// POST /api/uploads (field name: "file")
router.post("/", auth, upload.single("file"), (req, res) => {
  if (!req.file) return res.status(400).json({ message: "No file uploaded" });
  const fileUrl = `/uploads/${req.file.filename}`; // served statically by server.js
  res.json({ ok: true, url: fileUrl });
});

module.exports = router;
