// routes/auth.js - COMPLETE AUTH ROUTES
import express from "express";
import { pool } from "../db.js";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || "secret123";
const SALT_ROUNDS = 10;

// ============================================
// MIDDLEWARE
// ============================================

// Auth middleware - verify JWT token
const auth = (req, res, next) => {
  const authHeader = req.headers.authorization || "";
  
  if (!authHeader.startsWith("Bearer ")) {
    console.log("❌ No Bearer token provided");
    return res.status(401).json({ error: "No token provided" });
  }
  
  const token = authHeader.split(" ")[1];
  
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    console.log(`✅ Token verified for user ID: ${decoded.id}`);
    next();
  } catch (e) {
    console.error("❌ Token verification failed:", e.message);
    return res.status(401).json({ error: "Invalid or expired token" });
  }
};

// ============================================
// ROUTES
// ============================================

/**
 * POST /api/auth/register
 * Register new user
 */
router.post("/register", async (req, res) => {
  try {
    const { email, password, display_name, role } = req.body;
    
    console.log(`📝 Registration attempt for: ${email}`);
    
    if (!email || !password) {
      return res.status(400).json({ 
        error: "Email and password are required" 
      });
    }

    // Check if email already exists
    const [exists] = await pool.query(
      "SELECT id FROM users WHERE email = ?", 
      [email]
    );
    
    if (exists.length > 0) {
      console.log(`❌ Email already registered: ${email}`);
      return res.status(409).json({ error: "Email already registered" });
    }

    // Hash password
    const hash = await bcrypt.hash(password, SALT_ROUNDS);
    
    // Insert new user
    const [result] = await pool.query(
      "INSERT INTO users (email, password_hash, display_name, role, created_at) VALUES (?, ?, ?, ?, NOW())",
      [email, hash, display_name || null, role || 'user']
    );
    
    const userId = result.insertId;
    
    // Generate JWT token
    const token = jwt.sign(
      { id: userId, email, role: role || 'user' }, 
      JWT_SECRET, 
      { expiresIn: "30d" }
    );
    
    console.log(`✅ User registered successfully: ${email} (ID: ${userId})`);
    
    res.status(201).json({ 
      message: "Registration successful",
      token, 
      user: { 
        id: userId, 
        email, 
        display_name: display_name || null,
        role: role || 'user'
      } 
    });
  } catch (err) {
    console.error("❌ Registration error:", err);
    res.status(500).json({ error: "Server error", details: err.message });
  }
});

/**
 * POST /api/auth/login
 * Login user
 */
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body;
    
    console.log(`🔐 Login attempt for: ${email}`);
    
    if (!email || !password) {
      return res.status(400).json({ 
        error: "Email and password are required" 
      });
    }

    // Get user from database
    const [rows] = await pool.query(
      "SELECT id, email, password_hash, display_name, role FROM users WHERE email = ?", 
      [email]
    );
    
    if (rows.length === 0) {
      console.log(`❌ User not found: ${email}`);
      return res.status(401).json({ error: "Invalid credentials" });
    }
    
    const user = rows[0];
    
    // Verify password
    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    
    if (!passwordMatch) {
      console.log(`❌ Invalid password for: ${email}`);
      return res.status(401).json({ error: "Invalid credentials" });
    }
    
    // Generate JWT token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role }, 
      JWT_SECRET, 
      { expiresIn: "30d" }
    );
    
    console.log(`✅ Login successful: ${email} (Role: ${user.role})`);
    
    res.json({ 
      message: "Login successful",
      token, 
      user: { 
        id: user.id, 
        email: user.email, 
        display_name: user.display_name,
        role: user.role
      } 
    });
  } catch (err) {
    console.error("❌ Login error:", err);
    res.status(500).json({ error: "Server error", details: err.message });
  }
});

/**
 * GET /api/auth/me
 * Get current user profile
 */
router.get("/me", auth, async (req, res) => {
  try {
    const userId = req.user.id;
    
    console.log(`👤 Fetching profile for user ID: ${userId}`);
    
    // Get user from database
    const [rows] = await pool.query(
      "SELECT id, email, display_name, role, created_at FROM users WHERE id = ?",
      [userId]
    );
    
    if (rows.length === 0) {
      console.log(`❌ User not found: ${userId}`);
      return res.status(404).json({ error: "User not found" });
    }
    
    const user = rows[0];
    
    console.log(`✅ Profile fetched: ${user.email} (Role: ${user.role})`);
    
    res.json({ 
      success: true,
      user: {
        id: user.id,
        email: user.email,
        display_name: user.display_name,
        role: user.role,
        created_at: user.created_at
      }
    });
  } catch (err) {
    console.error("❌ Get profile error:", err);
    res.status(500).json({ error: "Server error", details: err.message });
  }
});

/**
 * POST /api/auth/verify
 * Verify JWT token
 */
router.post("/verify", auth, async (req, res) => {
  try {
    const userId = req.user.id;
    
    console.log(`🔍 Verifying token for user ID: ${userId}`);
    
    // Get fresh user data from database
    const [rows] = await pool.query(
      "SELECT id, email, display_name, role FROM users WHERE id = ?",
      [userId]
    );
    
    if (rows.length === 0) {
      console.log(`❌ User not found: ${userId}`);
      return res.status(404).json({ error: "User not found" });
    }
    
    const user = rows[0];
    
    console.log(`✅ Token verified for: ${user.email}`);
    
    res.json({ 
      valid: true,
      user: {
        id: user.id,
        email: user.email,
        display_name: user.display_name,
        role: user.role
      }
    });
  } catch (err) {
    console.error("❌ Token verification error:", err);
    res.status(500).json({ error: "Server error", details: err.message });
  }
});

/**
 * PUT /api/auth/profile
 * Update user profile
 */
router.put("/profile", auth, async (req, res) => {
  try {
    const userId = req.user.id;
    const { display_name, email } = req.body;
    
    console.log(`✏️ Updating profile for user ID: ${userId}`);
    
    const updateFields = [];
    const values = [];
    
    if (display_name !== undefined) {
      updateFields.push("display_name = ?");
      values.push(display_name);
    }
    
    if (email !== undefined) {
      // Check if new email is already taken
      const [exists] = await pool.query(
        "SELECT id FROM users WHERE email = ? AND id != ?",
        [email, userId]
      );
      
      if (exists.length > 0) {
        return res.status(409).json({ error: "Email already in use" });
      }
      
      updateFields.push("email = ?");
      values.push(email);
    }
    
    if (updateFields.length === 0) {
      return res.status(400).json({ error: "No fields to update" });
    }
    
    updateFields.push("updated_at = NOW()");
    values.push(userId);
    
    const query = `UPDATE users SET ${updateFields.join(", ")} WHERE id = ?`;
    
    await pool.query(query, values);
    
    // Get updated user data
    const [rows] = await pool.query(
      "SELECT id, email, display_name, role FROM users WHERE id = ?",
      [userId]
    );
    
    console.log(`✅ Profile updated for: ${rows[0].email}`);
    
    res.json({ 
      message: "Profile updated successfully",
      user: rows[0]
    });
  } catch (err) {
    console.error("❌ Update profile error:", err);
    res.status(500).json({ error: "Server error", details: err.message });
  }
});

/**
 * PUT /api/auth/password
 * Change user password
 */
router.put("/password", auth, async (req, res) => {
  try {
    const userId = req.user.id;
    const { current_password, new_password } = req.body;
    
    console.log(`🔑 Password change attempt for user ID: ${userId}`);
    
    if (!current_password || !new_password) {
      return res.status(400).json({ 
        error: "Current password and new password are required" 
      });
    }
    
    if (new_password.length < 6) {
      return res.status(400).json({ 
        error: "New password must be at least 6 characters" 
      });
    }
    
    // Get current user
    const [rows] = await pool.query(
      "SELECT password_hash FROM users WHERE id = ?",
      [userId]
    );
    
    if (rows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }
    
    // Verify current password
    const passwordMatch = await bcrypt.compare(
      current_password, 
      rows[0].password_hash
    );
    
    if (!passwordMatch) {
      console.log(`❌ Current password incorrect for user ID: ${userId}`);
      return res.status(401).json({ error: "Current password is incorrect" });
    }
    
    // Hash new password
    const newHash = await bcrypt.hash(new_password, SALT_ROUNDS);
    
    // Update password
    await pool.query(
      "UPDATE users SET password_hash = ?, updated_at = NOW() WHERE id = ?",
      [newHash, userId]
    );
    
    console.log(`✅ Password changed successfully for user ID: ${userId}`);
    
    res.json({ message: "Password changed successfully" });
  } catch (err) {
    console.error("❌ Change password error:", err);
    res.status(500).json({ error: "Server error", details: err.message });
  }
});

export default router;