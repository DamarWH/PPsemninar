// controllers/authController.js
import { pool } from "../db.js";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import dotenv from "dotenv";
dotenv.config();

const JWT_SECRET = process.env.JWT_SECRET || "secret_jwt_change_this";
const SALT_ROUNDS = 10;

export async function register(req, res) {
  try {
    const { display_name, email, password, role = "user" } = req.body;
    if (!display_name || !email || !password) {
      return res.status(400).json({ error: "display_name, email and password required" });
    }

    // check existing
    const [rows] = await pool.query("SELECT id FROM users WHERE email = ?", [email]);
    if (rows.length) return res.status(409).json({ error: "Email already registered" });

    const hashed = await bcrypt.hash(password, SALT_ROUNDS);
    const [result] = await pool.query(
      "INSERT INTO users (display_name, email, password_hash, role, created_at) VALUES (?, ?, ?, ?, NOW())",
      [display_name, email, hashed, role]
    );

    const userId = result.insertId;
    // create token
    const token = jwt.sign({ id: userId, email, role }, JWT_SECRET, { expiresIn: "30d" });

    return res.status(201).json({
      message: "User registered",
      token,
      user: { id: userId, email, display_name, role },
    });
  } catch (err) {
    console.error("register:", err);
    return res.status(500).json({ error: "Server error" });
  }
}

export async function login(req, res) {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: "email and password required" });

    const [rows] = await pool.query("SELECT id, display_name, email, password_hash, role FROM users WHERE email = ?", [email]);
    if (!rows.length) return res.status(401).json({ error: "Invalid credentials" });

    const user = rows[0];
    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) return res.status(401).json({ error: "Invalid credentials" });

    const token = jwt.sign({ id: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: "30d" });

    return res.json({
      message: "Login success",
      token,
      user: { id: user.id, email: user.email, display_name: user.display_name, role: user.role },
    });
  } catch (err) {
    console.error("login:", err);
    return res.status(500).json({ error: "Server error" });
  }
}

export async function verifyToken(req, res) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader) return res.status(401).json({ error: "Missing authorization header" });
    const token = authHeader.split(" ")[1];
    if (!token) return res.status(401).json({ error: "Missing token" });

    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      // optionally: fetch fresh user record to include latest role info
      const [rows] = await pool.query("SELECT id, email, display_name, role FROM users WHERE id = ?", [decoded.id]);
      if (!rows.length) return res.status(401).json({ error: "User not found" });

      const user = rows[0];
      return res.json({ valid: true, user: { id: user.id, email: user.email, display_name: user.display_name, role: user.role } });
    } catch (e) {
      return res.status(401).json({ error: "Token invalid" });
    }
  } catch (err) {
    console.error("verifyToken:", err);
    return res.status(500).json({ error: "Server error" });
  }
}