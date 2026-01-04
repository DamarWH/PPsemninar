// routes/keranjang.js
import express from "express";
import { pool } from "../db.js";
import jwt from "jsonwebtoken";

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || "secret123";

// Auth middleware
const auth = (req, res, next) => {
  const h = req.headers.authorization || "";
  if (!h.startsWith("Bearer ")) return res.status(401).json({ error: "No token" });
  const token = h.split(" ")[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (e) {
    return res.status(401).json({ error: "Invalid token" });
  }
};

// Helper: cek stock produk
async function getProductStock(productId) {
  // 🔥 PERBAIKAN: Gunakan 'stok' sesuai struktur database
  const [rows] = await pool.query(
    "SELECT id, stok, size_stock FROM products WHERE id = ? LIMIT 1", 
    [productId]
  );
  if (!rows || rows.length === 0) return null;
  const p = rows[0];
  let sizeStock = {};
  if (p.size_stock) {
    try {
      sizeStock = typeof p.size_stock === "object" ? p.size_stock : JSON.parse(p.size_stock);
    } catch (e) {
      sizeStock = {};
    }
  }
  // 🔥 PERBAIKAN: Gunakan 'stok' bukan 'stock'
  const stock = p.stok != null ? Number(p.stok) : null;
  return { stock, sizeStock };
}

// POST /api/cart - Tambah item ke cart
router.post("/", auth, async (req, res) => {
  try {
    const { user_id, product_id, nama, harga, foto, size, quantity } = req.body;
    const uid = user_id || req.user.id || req.user.email || req.user.sub || null;
    
    console.log("🔥 POST /api/cart received:", { user_id: uid, product_id, size, quantity });
    
    if (!uid) return res.status(400).json({ error: "user_id tidak tersedia" });
    if (!product_id) return res.status(400).json({ error: "product_id required" });

    // Validasi produk
    const prod = await getProductStock(product_id);
    if (!prod) {
      console.log("❌ Product not found:", product_id);
      return res.status(400).json({ error: "product not found" });
    }

    const qty = Number(quantity || 1);
    if (isNaN(qty) || qty < 1) return res.status(400).json({ error: "invalid quantity" });

    // Cek stock berdasarkan size
    if (size) {
      const sizeKey = Object.keys(prod.sizeStock).find(k => k.toString().toLowerCase() === size.toString().toLowerCase());
      const available = sizeKey ? Number(prod.sizeStock[sizeKey] ?? 0) : 0;
      console.log(`🔥 Stock check for size ${size}:`, available);
      if (available < qty) {
        console.log(`❌ Insufficient stock for size ${size}: requested ${qty}, available ${available}`);
        return res.status(400).json({ error: `insufficient stock for size ${size}` });
      }
    } else {
      if (prod.stock != null && prod.stock < qty) {
        console.log(`❌ Insufficient stock: requested ${qty}, available ${prod.stock}`);
        return res.status(400).json({ error: "insufficient stock" });
      }
    }

    const q = `INSERT INTO carts (user_id, product_id, nama, harga, foto, size, quantity)
               VALUES (?, ?, ?, ?, ?, ?, ?)`;
    const [r] = await pool.query(q, [uid, product_id, nama || null, harga || 0, foto || null, size || null, qty]);
    
    console.log("✅ Cart item added successfully, ID:", r.insertId);
    res.status(201).json({ id: r.insertId, success: true });
  } catch (err) {
    console.error("❌ POST /api/cart error:", err);
    res.status(500).json({ error: "server error", details: err.message });
  }
});

// GET /api/cart - Ambil cart user
router.get("/", auth, async (req, res) => {
  try {
    const uid = req.query.user_id || req.user.id || req.user.email || req.user.sub;
    if (!uid) return res.status(400).json({ error: "user_id tidak tersedia" });
    
    console.log("🔥 GET /api/cart for user:", uid);
    
    const [rows] = await pool.query("SELECT * FROM carts WHERE user_id = ? ORDER BY created_at DESC", [uid]);
    
    console.log(`✅ Found ${rows.length} cart items`);
    
    const normalized = rows.map(r => ({
      id: r.id,
      user_id: r.user_id,
      product_id: r.product_id,
      nama: r.nama,
      harga: Number(r.harga),
      foto: r.foto,
      size: r.size,
      quantity: Number(r.quantity),
      created_at: r.created_at,
    }));
    res.json(normalized);
  } catch (err) {
    console.error("❌ GET /api/cart error:", err);
    res.status(500).json({ error: "server error" });
  }
});

// PUT /api/cart/:id - Update quantity atau size
router.put("/:id", auth, async (req, res) => {
  try {
    const id = req.params.id;
    const { quantity, size } = req.body;
    
    console.log(`🔥 PUT /api/cart/${id}:`, { quantity, size });
    
    if ((quantity && (isNaN(Number(quantity)) || Number(quantity) < 1))) {
      return res.status(400).json({ error: "invalid quantity" });
    }

    const [rows] = await pool.query("SELECT * FROM carts WHERE id = ? LIMIT 1", [id]);
    if (!rows || rows.length === 0) return res.status(404).json({ error: "cart item not found" });
    const item = rows[0];

    const uid = req.user.id || req.user.email || req.user.sub;
    if (uid && item.user_id && uid.toString() !== item.user_id.toString()) {
      return res.status(403).json({ error: "forbidden" });
    }

    const newQty = quantity ? Number(quantity) : Number(item.quantity);
    const newSize = size !== undefined ? size : item.size;

    const prod = await getProductStock(item.product_id);
    if (!prod) return res.status(400).json({ error: "product not found" });

    if (newSize) {
      const sizeKey = Object.keys(prod.sizeStock).find(k => k.toString().toLowerCase() === newSize.toString().toLowerCase());
      const available = sizeKey ? Number(prod.sizeStock[sizeKey] ?? 0) : 0;
      if (available < newQty) return res.status(400).json({ error: `insufficient stock for size ${newSize}` });
    } else {
      if (prod.stock != null && prod.stock < newQty) return res.status(400).json({ error: "insufficient stock" });
    }

    await pool.query("UPDATE carts SET quantity = ?, size = ? WHERE id = ?", [newQty, newSize, id]);
    
    console.log(`✅ Cart item ${id} updated successfully`);
    res.json({ ok: true });
  } catch (err) {
    console.error("❌ PUT /api/cart/:id error:", err);
    res.status(500).json({ error: "server error" });
  }
});

// DELETE /api/cart/:id - Hapus item cart
router.delete("/:id", auth, async (req, res) => {
  try {
    const id = req.params.id;
    
    console.log(`🔥 DELETE /api/cart/${id}`);
    
    const [rows] = await pool.query("SELECT user_id FROM carts WHERE id = ? LIMIT 1", [id]);
    if (!rows || rows.length === 0) return res.status(404).json({ error: "not found" });
    
    const uid = req.user.id || req.user.email || req.user.sub;
    if (uid && rows[0].user_id && uid.toString() !== rows[0].user_id.toString()) {
      return res.status(403).json({ error: "forbidden" });
    }
    
    await pool.query("DELETE FROM carts WHERE id = ?", [id]);
    
    console.log(`✅ Cart item ${id} deleted successfully`);
    res.json({ ok: true });
  } catch (err) {
    console.error("❌ DELETE /api/cart/:id error:", err);
    res.status(500).json({ error: "server error" });
  }
});

export default router;