// routes/orders.js - WITH ADMIN REPORT ENDPOINT
import express from "express";
import { pool } from "../db.js";
import jwt from "jsonwebtoken";

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || "secret123";

// Auth middleware
const auth = (req, res, next) => {
  const h = req.headers.authorization || "";
  if (!h.startsWith("Bearer ")) {
    return res.status(401).json({ error: "No token" });
  }
  const token = h.split(" ")[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (e) {
    return res.status(401).json({ error: "Invalid token" });
  }
};

// Admin middleware
const isAdmin = (req, res, next) => {
  if (req.user?.role !== 'admin') {
    return res.status(403).json({ error: "Admin access required" });
  }
  next();
};

/**
 * 🆕 GET /api/orders/admin/report
 * Generate admin dashboard report
 */
router.get("/admin/report", auth, isAdmin, async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    if (!startDate || !endDate) {
      return res.status(400).json({ 
        error: "startDate and endDate are required" 
      });
    }

    console.log(`📊 Admin: Generating report from ${startDate} to ${endDate}`);

    // Query all orders in date range
    const query = `
      SELECT 
        id, order_id, user_id, name, email, phone,
        total_items, total_price, status, items,
        payment_method, shipping_method,
        created_at, paid_at
      FROM orders 
      WHERE DATE(created_at) BETWEEN ? AND ?
      ORDER BY created_at DESC
    `;

    const [transactions] = await pool.query(query, [startDate, endDate]);

    console.log(`✅ Admin: Found ${transactions.length} transactions in range`);

    // Return data ke Flutter untuk diproses
    return res.json({
      success: true,
      startDate,
      endDate,
      count: transactions.length,
      transactions: transactions.map(t => ({
        id: t.id,
        order_id: t.order_id,
        user_id: t.user_id,
        name: t.name,
        email: t.email,
        phone: t.phone,
        total_items: t.total_items,
        total_price: t.total_price, // ⭐ Snake case (dari DB)
        status: t.status,
        items: t.items, // JSON string dari DB
        payment_method: t.payment_method,
        shipping_method: t.shipping_method,
        created_at: t.created_at,
        paid_at: t.paid_at
      }))
    });

  } catch (err) {
    console.error("❌ GET /api/orders/admin/report error:", err);
    return res.status(500).json({ 
      error: "Server error", 
      details: err.message 
    });
  }
});

/**
 * POST /api/orders
 * Create new order
 */
router.post("/", auth, async (req, res) => {
  try {
    const {
      user_id,
      name,
      email,
      phone,
      address,
      city,
      postal_code,
      notes,
      total_items,
      total_price,
      status,
      items
    } = req.body;

    if (!user_id || !name || !total_price) {
      return res.status(400).json({ 
        error: "Missing required fields: user_id, name, total_price" 
      });
    }

    const orderId = `ORDER-${Date.now()}-${Math.random().toString(36).substr(2, 9).toUpperCase()}`;
    const itemsJson = items ? JSON.stringify(items) : null;

    const query = `
      INSERT INTO orders (
        order_id, user_id, name, email, phone, address, city, postal_code, notes, 
        total_items, total_price, status, items, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
    `;

    const [result] = await pool.query(query, [
      orderId,
      user_id,
      name,
      email || null,
      phone || null,
      address || null,
      city || null,
      postal_code || null,
      notes || null,
      total_items || 0,
      total_price,
      status || 'pending',
      itemsJson
    ]);

    console.log('✅ Order created:', orderId, '| DB ID:', result.insertId);

    return res.status(201).json({
      ok: true,
      orderId: orderId,
      order_id: orderId,
      dbId: result.insertId,
      message: "Order created successfully"
    });

  } catch (err) {
    console.error("POST /api/orders error:", err);
    if (!res.headersSent) {
      return res.status(500).json({ 
        error: "Server error", 
        details: err.message 
      });
    }
  }
});

/**
 * GET /api/orders/:user_id
 * Get all orders for a user
 */
router.get("/:user_id", auth, async (req, res) => {
  try {
    const { user_id } = req.params;
    const { status } = req.query;

    let query = `SELECT * FROM orders WHERE user_id = ?`;
    const params = [user_id];

    if (status) {
      query += ` AND status = ?`;
      params.push(status);
    }

    query += ` ORDER BY created_at DESC`;

    const [rows] = await pool.query(query, params);

    console.log(`✅ Found ${rows.length} orders for user ${user_id}`);

    return res.json({ orders: rows });

  } catch (err) {
    console.error("GET /api/orders/:user_id error:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * PUT /api/orders/:id
 * Update order status and payment info
 */
router.put("/:id", auth, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, payment_method, shipping_method } = req.body;

    if (!status) {
      return res.status(400).json({ error: "Status is required" });
    }

    const updateFields = ['status = ?'];
    const values = [status];

    if (payment_method) {
      updateFields.push('payment_method = ?');
      values.push(payment_method);
    }

    if (shipping_method) {
      updateFields.push('shipping_method = ?');
      values.push(shipping_method);
    }

    if (status === 'paid') {
      updateFields.push('paid_at = NOW()');
    }

    updateFields.push('updated_at = NOW()');
    values.push(id);

    const query = `UPDATE orders SET ${updateFields.join(', ')} WHERE id = ?`;
    const [result] = await pool.query(query, values);

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Order not found" });
    }

    console.log(`✅ Order ${id} updated:`, { status, payment_method, shipping_method });

    return res.json({ 
      ok: true, 
      message: "Order updated",
      status,
      payment_method,
      shipping_method
    });

  } catch (err) {
    console.error("PUT /api/orders/:id error:", err);
    return res.status(500).json({ 
      error: "Server error", 
      details: err.message 
    });
  }
});

/**
 * DELETE /api/orders/:id
 * Delete order (for cancelled/failed orders)
 */
router.delete("/:id", auth, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    const { id } = req.params;

    const [existing] = await connection.query(
      `SELECT id, status, items FROM orders WHERE id = ? LIMIT 1`,
      [id]
    );

    if (existing.length === 0) {
      connection.release();
      return res.status(404).json({ error: "Order not found" });
    }

    const order = existing[0];

    const allowedStatuses = ['pending', 'cancelled', 'failed'];
    if (!allowedStatuses.includes(order.status)) {
      connection.release();
      return res.status(400).json({ 
        error: "Cannot delete order", 
        message: `Only ${allowedStatuses.join(', ')} orders can be deleted` 
      });
    }

    await connection.beginTransaction();

    if (order.items && order.status === 'paid') {
      try {
        const items = JSON.parse(order.items);
        
        for (const item of items) {
          const productId = item.productId || item.produkId || item.id;
          const size = item.size || null;
          const quantity = parseInt(item.quantity || 1);

          const [products] = await connection.query(
            `SELECT stok, size_stock FROM products WHERE id = ?`,
            [productId]
          );

          if (products.length > 0) {
            const product = products[0];
            let sizeStock = product.size_stock ? JSON.parse(product.size_stock) : null;

            if (sizeStock && size) {
              sizeStock[size] = parseInt(sizeStock[size] || 0) + quantity;
              const totalStock = Object.values(sizeStock)
                .reduce((sum, val) => sum + parseInt(val || 0), 0);

              await connection.query(
                `UPDATE products SET stok = ?, size_stock = ? WHERE id = ?`,
                [totalStock, JSON.stringify(sizeStock), productId]
              );
            } else {
              const newStock = parseInt(product.stok || 0) + quantity;
              await connection.query(
                `UPDATE products SET stok = ? WHERE id = ?`,
                [newStock, productId]
              );
            }
          }
        }

        console.log(`✅ Stock restored for order ${id}`);
      } catch (e) {
        console.error('Error restoring stock:', e);
      }
    }

    await connection.query(`DELETE FROM orders WHERE id = ?`, [id]);
    await connection.commit();

    console.log(`✅ Order ${id} deleted`);

    return res.json({ 
      ok: true, 
      message: "Order deleted",
      deletedId: id
    });

  } catch (err) {
    await connection.rollback();
    console.error("DELETE /api/orders/:id error:", err);
    return res.status(500).json({ 
      error: "Server error", 
      details: err.message 
    });
  } finally {
    connection.release();
  }
});

/**
 * GET /api/orders/detail/:id
 * Get single order detail by database ID
 */
router.get("/detail/:id", auth, async (req, res) => {
  try {
    const { id } = req.params;

    const [rows] = await pool.query(
      `SELECT * FROM orders WHERE id = ? LIMIT 1`,
      [id]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Order not found" });
    }

    const order = rows[0];

    if (order.items && typeof order.items === 'string') {
      try {
        order.items = JSON.parse(order.items);
      } catch (e) {
        console.error('Error parsing items:', e);
      }
    }

    return res.json({ order });

  } catch (err) {
    console.error("GET /api/orders/detail/:id error:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

/**
 * GET /api/orders/by-order-id/:orderId
 * Get single order by Order ID (ORDER-xxxxx format)
 */
router.get("/by-order-id/:orderId", auth, async (req, res) => {
  try {
    const { orderId } = req.params;

    console.log(`🔍 Searching for order: ${orderId}`);

    const [rows] = await pool.query(
      `SELECT * FROM orders WHERE order_id = ? OR id = ? LIMIT 1`,
      [orderId, orderId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ 
        error: "Order not found",
        orderId: orderId
      });
    }

    const order = rows[0];

    if (order.items && typeof order.items === 'string') {
      try {
        order.items = JSON.parse(order.items);
      } catch (e) {
        console.error('Error parsing items:', e);
      }
    }

    console.log(`✅ Order found: ${order.order_id} (DB ID: ${order.id})`);

    return res.json({ order });

  } catch (err) {
    console.error("GET /api/orders/by-order-id error:", err);
    return res.status(500).json({ 
      error: "Server error", 
      details: err.message 
    });
  }
});

/**
 * GET /api/orders/stats/:user_id
 * Get order statistics for a user
 */
router.get("/stats/:user_id", auth, async (req, res) => {
  try {
    const { user_id } = req.params;

    const [stats] = await pool.query(`
      SELECT 
        COUNT(*) as total_orders,
        SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) as completed_orders,
        SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_orders,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_orders,
        SUM(CASE WHEN status = 'paid' THEN total_price ELSE 0 END) as total_spent
      FROM orders
      WHERE user_id = ?
    `, [user_id]);

    return res.json({ stats: stats[0] });

  } catch (err) {
    console.error("GET /api/orders/stats error:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

export default router;