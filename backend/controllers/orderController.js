// controllers/orderController.js
import { pool } from "../db.js";

export async function getOrders(req, res) {
  try {
    const [rows] = await pool.query("SELECT * FROM orders ORDER BY created_at DESC");
    res.json(rows);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
}

export async function getOrderDetail(req, res) {
  try {
    const id = req.params.id;
    const [[order]] = await pool.query("SELECT * FROM orders WHERE id = ?", [id]);
    if (!order) return res.status(404).json({ error: "Order not found" });
    const [items] = await pool.query("SELECT * FROM order_items WHERE order_id = ?", [id]);
    res.json({ ...order, items });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
}

export async function updateOrderStatus(req, res) {
  try {
    const id = req.params.id;
    const { status } = req.body;
    await pool.query("UPDATE orders SET status = ? WHERE id = ?", [status, id]);
    res.json({ message: "Status updated" });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
}