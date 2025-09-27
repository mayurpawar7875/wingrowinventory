// backend/controllers/authController.js
const jwt = require("jsonwebtoken");
const User = require("../models/User");

const ALLOWED_ROLES = ["organizer", "manager"];

const sign = (u) =>
  jwt.sign(
    { _id: String(u._id), userId: u.userId, role: u.role },
    process.env.JWT_SECRET,
    { expiresIn: "7d" }
  );

// POST /api/auth/register
async function register(req, res) {
  try {
    const { userId, password, role = "organizer" } = req.body;

    if (!userId || !password)
      return res.status(400).json({ message: "userId and password required" });

    if (!ALLOWED_ROLES.includes(role))
      return res.status(400).json({ message: "role must be 'organizer' or 'manager'" });

    const exists = await User.findOne({ userId });
    if (exists) return res.status(409).json({ message: "userId already exists" });

    // Model should hash `password` in pre-save
    const user = new User({ userId, password, role });
    await user.save();

    return res.status(201).json({ ok: true, user: { userId: user.userId, role: user.role } });
  } catch (e) {
    return res.status(500).json({ message: e.message });
  }
}

// POST /api/auth/login
async function login(req, res) {
  try {
    const { userId, password } = req.body;

    const user = await User.findOne({ userId });
    if (!user) return res.status(401).json({ message: "Invalid credentials" });

    const ok = await user.matchPassword(password); // compares with hashed `password` in DB
    if (!ok) return res.status(401).json({ message: "Invalid credentials" });

    const token = sign(user);
    return res.json({ ok: true, token, user: { userId: user.userId, role: user.role } });
  } catch (e) {
    return res.status(500).json({ message: e.message });
  }
}

// optional
function logout(_req, res) {
  res.clearCookie?.("token");
  res.json({ ok: true });
}
function me(req, res) {
  res.json({ user: req.user });
}

module.exports = { register, login, logout, me };
