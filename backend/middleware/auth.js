// backend/middleware/auth.js
const jwt = require("jsonwebtoken");

module.exports = function auth(req, res, next) {
  try {
    const h = req.headers.authorization || "";
    const token = h.startsWith("Bearer ") ? h.slice(7) : null;
    if (!token) return res.status(401).json({ message: "No token provided" });

    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = payload; // {_id, userId, role, iat, exp}
    next();
  } catch (e) {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
};
