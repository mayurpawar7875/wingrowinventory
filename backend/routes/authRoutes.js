// backend/routes/authRoutes.js
const express = require("express");
const router = express.Router();

const auth = require("../middleware/auth"); // must be a function
const { register, login, me, logout } = require("../controllers/authController");

// helpful startup sanity logs (you can remove once it works)
console.log("auth typeof:", typeof auth);                 // should be 'function'
console.log("register typeof:", typeof register);         // 'function'
console.log("login typeof:", typeof login);               // 'function'
console.log("me typeof:", typeof me);                     // 'function'
console.log("logout typeof:", typeof logout);             // 'function'

// public
router.post("/register", register);
router.post("/login", login);

// protected
router.get("/me", auth, me);

// optional
router.post("/logout", logout);

module.exports = router;
