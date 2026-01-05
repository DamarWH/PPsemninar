// routes/admin.js - ABSOLUTE FINAL FIX WITH DEBUGGING
import express from "express";
import { pool } from "../db.js";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || "secret123";
const SALT_ROUNDS = 10;

console.log("✅ Admin routes module loaded");

// ============================================
// MIDDLEWARE
// ============================================

const auth = (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || "";
    
    if (!authHeader.startsWith("Bearer ")) {
      console.log("❌ [AUTH] No Bearer token provided");
      return res.status(401).json({ error: "No token provided" });
    }
    
    const token = authHeader.split(" ")[1];
    const decoded = jwt.verify(token, JWT_SECRET);
    
    req.user = {
      id: Number(decoded.id),
      email: decoded.email,
      role: decoded.role
    };
    
    console.log(`✅ Token verified for user ID: ${req.user.id}`);
    next();
  } catch (e) {
    console.error("❌ [AUTH] Token verification failed:", e.message);
    return res.status(401).json({ error: "Invalid or expired token" });
  }
};

const requireAdmin = (req, res, next) => {
  if (!req.user) {
    console.log("❌ [ADMIN] No user in request");
    return res.status(401).json({ error: "Authentication required" });
  }
  
  if (req.user.role !== 'admin') {
    console.log(`❌ [ADMIN] Access denied for ${req.user.email} (Role: ${req.user.role})`);
    return res.status(403).json({ error: "Admin access required" });
  }
  
  console.log(`✅ Admin access granted for: ${req.user.email}`);
  next();
};

// ============================================
// HELPER FUNCTIONS
// ============================================

function toInt(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') return Math.floor(value);
  if (typeof value === 'string') {
    const parsed = parseInt(value, 10);
    return isNaN(parsed) ? null : parsed;
  }
  if (typeof value === 'bigint') return Number(value);
  return null;
}

function toStr(value, defaultValue = '') {
  if (value === null || value === undefined) return defaultValue;
  return String(value);
}

function safeAdminResponse(admin, currentUserId) {
  const adminId = toInt(admin.id);
  const currentId = toInt(currentUserId);
  
  const response = {
    id: adminId,
    email: toStr(admin.email),
    display_name: toStr(admin.display_name),
    role: toStr(admin.role, 'admin'),
    created_at: admin.created_at ? new Date(admin.created_at).toISOString() : null,
    is_current_user: adminId === currentId
  };
  
  // Debug log to verify types
  console.log(`  📦 Admin ${adminId} (${typeof adminId}): ${response.email}`);
  
  return response;
}

// ============================================
// ROUTES
// ============================================

/**
 * GET /api/admin/list
 * Get list of all admins
 */
router.get("/list", auth, requireAdmin, async (req, res) => {
  console.log("\n" + "=".repeat(60));
  console.log("📋 [ADMIN LIST] Request received");
  console.log("=".repeat(60));
  
  try {
    const currentUserId = toInt(req.user.id);
    console.log(`👤 Current user: ${req.user.email} (ID: ${currentUserId}, type: ${typeof currentUserId})`);
    
    const [admins] = await pool.query(
      "SELECT id, email, display_name, role, created_at FROM users WHERE role = 'admin' ORDER BY created_at DESC"
    );
    
    console.log(`✅ Found ${admins.length} admin(s) in database`);
    
    if (admins.length > 0) {
      console.log("📦 Processing admins:");
      const processedAdmins = admins.map(admin => {
        try {
          return safeAdminResponse(admin, currentUserId);
        } catch (err) {
          console.error(`❌ Error processing admin ${admin.id}:`, err);
          return null;
        }
      }).filter(admin => admin !== null);
      
      console.log(`✅ Successfully processed ${processedAdmins.length} admin(s)`);
      console.log("📤 Sending response...");
      console.log("=".repeat(60) + "\n");
      
      return res.json({
        success: true,
        admins: processedAdmins
      });
    } else {
      console.log("⚠️ No admins found in database");
      console.log("=".repeat(60) + "\n");
      
      return res.json({
        success: true,
        admins: []
      });
    }
  } catch (err) {
    console.error("❌ [ADMIN LIST] Error:", err);
    console.error("Stack:", err.stack);
    console.log("=".repeat(60) + "\n");
    
    return res.status(500).json({ 
      error: "Server error", 
      message: err.message 
    });
  }
});

/**
 * POST /api/admin/create
 * Create new admin
 */
router.post("/create", auth, requireAdmin, async (req, res) => {
  console.log("\n" + "=".repeat(60));
  console.log("👤 [ADMIN CREATE] Request received");
  console.log("=".repeat(60));
  
  try {
    const { email, password, display_name } = req.body;
    
    console.log(`📧 Creating admin: ${email}`);
    console.log(`👤 Requested by: ${req.user.email}`);
    console.log(`📦 Display name: ${display_name}`);
    
    // Validation
    if (!email || !password || !display_name) {
      console.log("❌ Missing required fields");
      return res.status(400).json({ 
        error: "Email, password, and display_name are required" 
      });
    }
    
    if (password.length < 6) {
      console.log("❌ Password too short");
      return res.status(400).json({ 
        error: "Password must be at least 6 characters" 
      });
    }
    
    if (!email.includes('@')) {
      console.log("❌ Invalid email format");
      return res.status(400).json({ 
        error: "Invalid email format" 
      });
    }

    // Check existing
    const [exists] = await pool.query(
      "SELECT id, role FROM users WHERE email = ?", 
      [email]
    );
    
    if (exists.length > 0) {
      console.log(`❌ Email already exists: ${email}`);
      return res.status(409).json({ 
        error: "Email already registered" 
      });
    }

    // Hash password
    const hash = await bcrypt.hash(password, SALT_ROUNDS);
    console.log("✅ Password hashed");
    
    // Insert admin
    const [result] = await pool.query(
      "INSERT INTO users (email, password_hash, display_name, role, created_at) VALUES (?, ?, ?, 'admin', NOW())",
      [email, hash, display_name]
    );
    
    const adminId = toInt(result.insertId);
    console.log(`✅ Admin created with ID: ${adminId} (type: ${typeof adminId})`);
    console.log("=".repeat(60) + "\n");
    
    return res.status(201).json({ 
      success: true,
      message: "Admin created successfully",
      admin: { 
        id: adminId,
        email: toStr(email), 
        display_name: toStr(display_name),
        role: 'admin'
      } 
    });
  } catch (err) {
    console.error("❌ [ADMIN CREATE] Error:", err);
    console.error("Stack:", err.stack);
    console.log("=".repeat(60) + "\n");
    
    return res.status(500).json({ 
      error: "Server error", 
      message: err.message 
    });
  }
});

/**
 * DELETE /api/admin/delete/:id
 * Delete admin
 */
router.delete("/delete/:id", auth, requireAdmin, async (req, res) => {
  console.log("\n" + "=".repeat(60));
  console.log("🗑️ [ADMIN DELETE] Request received");
  console.log("=".repeat(60));
  
  try {
    const adminIdToDelete = toInt(req.params.id);
    const currentAdminId = toInt(req.user.id);
    
    console.log(`🎯 Target admin ID: ${adminIdToDelete}`);
    console.log(`👤 Current admin ID: ${currentAdminId}`);
    
    if (!adminIdToDelete) {
      console.log("❌ Invalid admin ID");
      return res.status(400).json({ error: "Invalid admin ID" });
    }
    
    if (adminIdToDelete === currentAdminId) {
      console.log("❌ Cannot delete self");
      return res.status(403).json({ 
        error: "Cannot delete your own admin account" 
      });
    }

    const [rows] = await pool.query(
      "SELECT id, email, display_name, role FROM users WHERE id = ?",
      [adminIdToDelete]
    );
    
    if (rows.length === 0) {
      console.log("❌ Admin not found");
      return res.status(404).json({ error: "Admin not found" });
    }
    
    const targetUser = rows[0];
    
    if (targetUser.role !== 'admin') {
      console.log(`❌ User is not admin: ${targetUser.email}`);
      return res.status(400).json({ 
        error: "User is not an admin" 
      });
    }
    
    await pool.query("DELETE FROM users WHERE id = ?", [adminIdToDelete]);
    
    console.log(`✅ Admin deleted: ${targetUser.email}`);
    console.log("=".repeat(60) + "\n");
    
    return res.json({ 
      success: true,
      message: "Admin deleted successfully",
      deleted_admin: {
        id: toInt(targetUser.id),
        email: toStr(targetUser.email),
        display_name: toStr(targetUser.display_name)
      }
    });
  } catch (err) {
    console.error("❌ [ADMIN DELETE] Error:", err);
    console.log("=".repeat(60) + "\n");
    
    return res.status(500).json({ 
      error: "Server error", 
      message: err.message 
    });
  }
});

/**
 * GET /api/admin/stats
 * Get admin statistics
 */
router.get("/stats", auth, requireAdmin, async (req, res) => {
  try {
    console.log(`📊 [ADMIN STATS] Request by: ${req.user.email}`);
    
    const [adminCount] = await pool.query(
      "SELECT COUNT(*) as total FROM users WHERE role = 'admin'"
    );
    
    const [userCount] = await pool.query(
      "SELECT COUNT(*) as total FROM users WHERE role = 'user'"
    );
    
    const [recentAdmins] = await pool.query(
      "SELECT id, email, display_name, created_at FROM users WHERE role = 'admin' ORDER BY created_at DESC LIMIT 5"
    );
    
    return res.json({
      success: true,
      stats: {
        total_admins: toInt(adminCount[0].total) || 0,
        total_users: toInt(userCount[0].total) || 0,
        recent_admins: recentAdmins.map(admin => ({
          id: toInt(admin.id),
          email: toStr(admin.email),
          display_name: toStr(admin.display_name),
          created_at: admin.created_at ? new Date(admin.created_at).toISOString() : null
        }))
      }
    });
  } catch (err) {
    console.error("❌ [ADMIN STATS] Error:", err);
    return res.status(500).json({ 
      error: "Server error", 
      message: err.message 
    });
  }
});

console.log("✅ Admin routes registered:");
console.log("  GET    /api/admin/list");
console.log("  POST   /api/admin/create");
console.log("  DELETE /api/admin/delete/:id");
console.log("  GET    /api/admin/stats");

export default router;