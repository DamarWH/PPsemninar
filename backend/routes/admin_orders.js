// routes/admin_orders.js - COMPLETE ADMIN ROUTES
import express from "express";
import { pool } from "../db.js";
import jwt from "jsonwebtoken";

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || "secret123";

// ============================================
// MIDDLEWARE
// ============================================

// Auth middleware
const auth = (req, res, next) => {
  const h = req.headers.authorization || "";
  if (!h.startsWith("Bearer ")) {
    console.log("❌ No Bearer token provided");
    return res.status(401).json({ error: "No token provided" });
  }
  const token = h.split(" ")[1];
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

// Admin check middleware
const isAdmin = async (req, res, next) => {
  try {
    const userId = req.user.id || req.user.userId || req.user.user_id;

    if (!userId) {
      console.log("❌ User ID not found in token");
      return res.status(401).json({ error: "User ID not found in token" });
    }

    console.log(`🔍 Checking admin status for user ID: ${userId}`);

    const [users] = await pool.query(
      `SELECT id, email, role FROM users WHERE id = ? LIMIT 1`,
      [userId]
    );

    if (users.length === 0) {
      console.log(`❌ User not found in database: ${userId}`);
      return res.status(404).json({ error: "User not found" });
    }

    const user = users[0];
    const isUserAdmin = user.role === 'admin';

    if (!isUserAdmin) {
      console.log(`❌ User ${user.email} is not admin. Role: ${user.role}`);
      return res.status(403).json({ 
        error: "Access denied. Admin privileges required.",
        userRole: user.role
      });
    }

    console.log(`✅ Admin verified: ${user.email}`);
    req.adminUser = user;
    next();
  } catch (err) {
    console.error("❌ Admin check error:", err);
    return res.status(500).json({ 
      error: "Failed to verify admin status",
      details: err.message 
    });
  }
};

// ============================================
// ADMIN ROUTES
// ============================================

/**
 * GET /api/admin/orders
 * Get all orders (Admin only)
 */
router.get("/", auth, isAdmin, async (req, res) => {
  try {
    const { status } = req.query;

    let query = `SELECT * FROM orders`;
    const params = [];

    // Filter by status if provided
    if (status && status !== 'all') {
      query += ` WHERE status = ?`;
      params.push(status);
    } else {
      // Exclude deleted orders by default
      query += ` WHERE status != 'deleted'`;
    }

    query += ` ORDER BY created_at DESC`;

    console.log(`🔍 Admin query: ${query}`, params);

    const [rows] = await pool.query(query, params);

    console.log(`✅ Admin: Found ${rows.length} orders`);

    // Parse items JSON for each order
    const orders = rows.map(order => {
      if (order.items && typeof order.items === 'string') {
        try {
          order.items = JSON.parse(order.items);
        } catch (e) {
          console.error('⚠️ Error parsing items for order', order.id, ':', e.message);
        }
      }
      return order;
    });

    return res.json({ 
      success: true,
      count: orders.length,
      orders 
    });

  } catch (err) {
    console.error("❌ GET /api/admin/orders error:", err);
    return res.status(500).json({ 
      error: "Server error",
      details: err.message 
    });
  }
});

/**
 * GET /api/admin/orders/:orderId
 * Get single order detail (Admin only)
 */
router.get("/:orderId", auth, isAdmin, async (req, res) => {
  try {
    const { orderId } = req.params;

    console.log(`🔍 Admin searching for order: ${orderId}`);

    // Search by both id and order_id
    const [rows] = await pool.query(
      `SELECT * FROM orders WHERE id = ? OR order_id = ? LIMIT 1`,
      [orderId, orderId]
    );

    if (rows.length === 0) {
      console.log(`❌ Order not found: ${orderId}`);
      return res.status(404).json({ 
        error: "Order not found",
        orderId 
      });
    }

    const order = rows[0];

    // Parse items JSON
    if (order.items && typeof order.items === 'string') {
      try {
        order.items = JSON.parse(order.items);
      } catch (e) {
        console.error('⚠️ Error parsing items:', e.message);
      }
    }

    console.log(`✅ Admin: Order found: ${order.order_id || order.id}`);

    return res.json({ 
      success: true,
      order 
    });

  } catch (err) {
    console.error("❌ GET /api/admin/orders/:orderId error:", err);
    return res.status(500).json({ 
      error: "Server error",
      details: err.message 
    });
  }
});

/**
 * PUT /api/admin/orders/:orderId/status
 * Update order status (Admin only)
 */
router.put("/:orderId/status", auth, isAdmin, async (req, res) => {
  try {
    const { orderId } = req.params;
    const { status } = req.body;

    console.log(`🔄 Admin updating order ${orderId} to status: ${status}`);

    if (!status) {
      return res.status(400).json({ error: "Status is required" });
    }

    // Validasi status
    const validStatuses = [
      'pending', 
      'paid', 
      'processing', 
      'shipping', 
      'completed', 
      'cancelled', 
      'failed'
    ];
    
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ 
        error: "Invalid status value",
        validStatuses,
        received: status
      });
    }

    const updateFields = ['status = ?', 'updated_at = NOW()'];
    const values = [status];

    // Jika status menjadi paid atau completed, set paid_at
    if (status === 'paid' || status === 'completed') {
      updateFields.splice(1, 0, 'paid_at = NOW()');
    }

    values.push(orderId);

    const query = `UPDATE orders SET ${updateFields.join(', ')} WHERE id = ?`;
    
    console.log(`📝 Executing query: ${query}`, values);
    
    const [result] = await pool.query(query, values);

    if (result.affectedRows === 0) {
      console.log(`❌ Order not found: ${orderId}`);
      return res.status(404).json({ error: "Order not found" });
    }

    console.log(`✅ Admin: Order ${orderId} status updated to ${status}`);

    return res.json({
      success: true,
      message: "Order status updated successfully",
      orderId,
      newStatus: status,
      affectedRows: result.affectedRows
    });

  } catch (err) {
    console.error("❌ PUT /api/admin/orders/:orderId/status error:", err);
    return res.status(500).json({ 
      error: "Server error",
      details: err.message 
    });
  }
});

/**
 * PUT /api/admin/orders/:orderId/tracking
 * Add tracking number (Admin only)
 */
router.put("/:orderId/tracking", auth, isAdmin, async (req, res) => {
  try {
    const { orderId } = req.params;
    const { trackingNumber, status } = req.body;

    console.log(`📦 Admin adding tracking to order ${orderId}: ${trackingNumber}`);

    if (!trackingNumber || trackingNumber.trim() === '') {
      return res.status(400).json({ error: "Tracking number is required" });
    }

    // Update tracking number dan optionally status
    const newStatus = status || 'shipping';

    const query = `
      UPDATE orders 
      SET tracking_number = ?, 
          status = ?,
          updated_at = NOW()
      WHERE id = ?
    `;

    console.log(`📝 Executing query: ${query}`, [trackingNumber, newStatus, orderId]);

    const [result] = await pool.query(query, [trackingNumber, newStatus, orderId]);

    if (result.affectedRows === 0) {
      console.log(`❌ Order not found: ${orderId}`);
      return res.status(404).json({ error: "Order not found" });
    }

    console.log(`✅ Admin: Tracking added to order ${orderId}: ${trackingNumber}`);

    return res.json({
      success: true,
      message: "Tracking number added successfully",
      orderId,
      trackingNumber,
      status: newStatus,
      affectedRows: result.affectedRows
    });

  } catch (err) {
    console.error("❌ PUT /api/admin/orders/:orderId/tracking error:", err);
    return res.status(500).json({ 
      error: "Server error",
      details: err.message 
    });
  }
});

/**
 * GET /api/admin/orders/status/:status
 * Get orders by status (Admin only)
 */
router.get("/status/:status", auth, isAdmin, async (req, res) => {
  try {
    const { status } = req.params;

    const query = `
      SELECT * FROM orders
      WHERE status = ?
      ORDER BY created_at DESC
    `;

    console.log(`🔍 Admin: Fetching orders with status: ${status}`);

    const [rows] = await pool.query(query, [status]);

    console.log(`✅ Admin: Found ${rows.length} orders with status ${status}`);

    // Parse items JSON
    const orders = rows.map(order => {
      if (order.items && typeof order.items === 'string') {
        try {
          order.items = JSON.parse(order.items);
        } catch (e) {
          console.error('⚠️ Error parsing items:', e.message);
        }
      }
      return order;
    });

    return res.json({ 
      success: true,
      status,
      count: orders.length,
      orders 
    });

  } catch (err) {
    console.error("❌ GET /api/admin/orders/status/:status error:", err);
    return res.status(500).json({ 
      error: "Server error",
      details: err.message 
    });
  }
});

/**
 * DELETE /api/admin/orders/:orderId
 * Delete order (Admin only - Soft delete)
 */
router.delete("/:orderId", auth, isAdmin, async (req, res) => {
  try {
    const { orderId } = req.params;

    console.log(`🗑️ Admin: Soft deleting order ${orderId}`);

    // Soft delete - ubah status menjadi 'deleted'
    const query = `
      UPDATE orders 
      SET status = 'deleted', updated_at = NOW()
      WHERE id = ?
    `;

    const [result] = await pool.query(query, [orderId]);

    if (result.affectedRows === 0) {
      console.log(`❌ Order not found: ${orderId}`);
      return res.status(404).json({ error: "Order not found" });
    }

    console.log(`✅ Admin: Order ${orderId} deleted (soft delete)`);

    return res.json({
      success: true,
      message: "Order deleted successfully",
      orderId,
      affectedRows: result.affectedRows
    });

  } catch (err) {
    console.error("❌ DELETE /api/admin/orders/:orderId error:", err);
    return res.status(500).json({ 
      error: "Server error",
      details: err.message 
    });
  }
});

/**
 * GET /api/admin/orders/stats/overview
 * Get admin statistics (Admin only)
 */
router.get("/stats/overview", auth, isAdmin, async (req, res) => {
  try {
    console.log(`📊 Admin: Fetching statistics`);

    const [stats] = await pool.query(`
      SELECT 
        COUNT(*) as total_orders,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_orders,
        SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) as paid_orders,
        SUM(CASE WHEN status = 'processing' THEN 1 ELSE 0 END) as processing_orders,
        SUM(CASE WHEN status = 'shipping' THEN 1 ELSE 0 END) as shipping_orders,
        SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_orders,
        SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) as cancelled_orders,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_orders,
        SUM(total_price) as total_revenue,
        SUM(CASE WHEN status IN ('completed', 'paid') THEN total_price ELSE 0 END) as completed_revenue
      FROM orders
      WHERE status != 'deleted'
    `);

    console.log(`✅ Admin: Statistics fetched`);

    return res.json({ 
      success: true,
      stats: stats[0] 
    });

  } catch (err) {
    console.error("❌ GET /api/admin/orders/stats/overview error:", err);
    return res.status(500).json({ 
      error: "Server error",
      details: err.message 
    });
  }
});

export default router;