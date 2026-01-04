// routes/inventory.js
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

/**
 * POST /api/inventory/reduce-stock
 * Mengurangi stok produk setelah pembayaran berhasil
 * Body: { items: [{ productId, size, quantity }] }
 */
router.post("/reduce-stock", auth, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    const { items } = req.body;

    if (!items || !Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ 
        error: "Items array is required",
        received: items 
      });
    }

    console.log('🔄 Starting stock reduction for', items.length, 'items');

    await connection.beginTransaction();

    const results = [];
    const errors = [];

    for (const item of items) {
      try {
        const productId = item.productId || item.produkId || item.id || item.product_id;
        const size = item.size || null;
        const quantity = parseInt(item.quantity || item.jumlah || 1);

        if (!productId) {
          errors.push({ item, error: "Missing product ID" });
          continue;
        }

        // 1. Ambil data produk
        const [products] = await connection.query(
          `SELECT id, nama, stok, size_stock FROM products WHERE id = ?`,
          [productId]
        );

        if (products.length === 0) {
          errors.push({ productId, error: "Product not found" });
          continue;
        }

        const product = products[0];
        
        // 2. Cek apakah produk menggunakan size_stock
        let sizeStock = null;
        if (product.size_stock) {
          try {
            sizeStock = typeof product.size_stock === 'string' 
              ? JSON.parse(product.size_stock) 
              : product.size_stock;
          } catch (e) {
            console.error('Error parsing size_stock:', e);
          }
        }

        // 3. Update stok
        if (sizeStock && size) {
          // Jika ada size_stock dan size ditentukan
          const currentSizeStock = parseInt(sizeStock[size] || 0);
          
          if (currentSizeStock < quantity) {
            errors.push({ 
              productId, 
              size, 
              error: `Insufficient stock. Available: ${currentSizeStock}, Requested: ${quantity}` 
            });
            continue;
          }

          // Kurangi stok size
          sizeStock[size] = currentSizeStock - quantity;
          
          // Update total stok
          const totalStock = Object.values(sizeStock).reduce((sum, val) => sum + parseInt(val || 0), 0);

          await connection.query(
            `UPDATE products SET stok = ?, size_stock = ? WHERE id = ?`,
            [totalStock, JSON.stringify(sizeStock), productId]
          );

          results.push({
            productId,
            productName: product.nama,
            size,
            reducedBy: quantity,
            remainingStock: sizeStock[size],
            totalStock: totalStock
          });

          console.log(`✅ Stock reduced: ${product.nama} (${size}) - ${quantity} items`);

        } else {
          // Jika tidak ada size_stock atau size tidak ditentukan
          const currentStock = parseInt(product.stok || 0);
          
          if (currentStock < quantity) {
            errors.push({ 
              productId, 
              error: `Insufficient stock. Available: ${currentStock}, Requested: ${quantity}` 
            });
            continue;
          }

          const newStock = currentStock - quantity;

          await connection.query(
            `UPDATE products SET stok = ? WHERE id = ?`,
            [newStock, productId]
          );

          results.push({
            productId,
            productName: product.nama,
            reducedBy: quantity,
            remainingStock: newStock
          });

          console.log(`✅ Stock reduced: ${product.nama} - ${quantity} items, remaining: ${newStock}`);
        }

      } catch (itemError) {
        console.error('Error processing item:', itemError);
        errors.push({ item, error: itemError.message });
      }
    }

    // Jika ada error pada item manapun, rollback
    if (errors.length > 0 && results.length === 0) {
      await connection.rollback();
      return res.status(400).json({ 
        error: "Failed to reduce stock for all items",
        errors: errors 
      });
    }

    // Jika ada beberapa sukses, commit
    await connection.commit();

    console.log(`✅ Stock reduction completed: ${results.length} success, ${errors.length} errors`);

    res.json({ 
      success: true,
      message: "Stock reduced successfully",
      results: results,
      errors: errors.length > 0 ? errors : undefined
    });

  } catch (error) {
    await connection.rollback();
    console.error("POST /api/inventory/reduce-stock error:", error);
    res.status(500).json({ 
      error: "Server error", 
      details: error.message 
    });
  } finally {
    connection.release();
  }
});

/**
 * POST /api/inventory/restore-stock
 * Mengembalikan stok jika order dibatalkan
 * Body: { items: [{ productId, size, quantity }] }
 */
router.post("/restore-stock", auth, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    const { items } = req.body;

    if (!items || !Array.isArray(items)) {
      return res.status(400).json({ error: "Items array is required" });
    }

    await connection.beginTransaction();

    const results = [];

    for (const item of items) {
      const productId = item.productId || item.produkId || item.id;
      const size = item.size || null;
      const quantity = parseInt(item.quantity || 1);

      const [products] = await connection.query(
        `SELECT id, nama, stok, size_stock FROM products WHERE id = ?`,
        [productId]
      );

      if (products.length === 0) continue;

      const product = products[0];
      let sizeStock = null;

      if (product.size_stock) {
        try {
          sizeStock = typeof product.size_stock === 'string' 
            ? JSON.parse(product.size_stock) 
            : product.size_stock;
        } catch (e) {
          console.error('Error parsing size_stock:', e);
        }
      }

      if (sizeStock && size) {
        sizeStock[size] = parseInt(sizeStock[size] || 0) + quantity;
        const totalStock = Object.values(sizeStock).reduce((sum, val) => sum + parseInt(val || 0), 0);

        await connection.query(
          `UPDATE products SET stok = ?, size_stock = ? WHERE id = ?`,
          [totalStock, JSON.stringify(sizeStock), productId]
        );

        results.push({ productId, size, restored: quantity });
      } else {
        const newStock = parseInt(product.stok || 0) + quantity;

        await connection.query(
          `UPDATE products SET stok = ? WHERE id = ?`,
          [newStock, productId]
        );

        results.push({ productId, restored: quantity });
      }
    }

    await connection.commit();

    console.log(`✅ Stock restored for ${results.length} items`);

    res.json({ 
      success: true,
      message: "Stock restored successfully",
      results: results
    });

  } catch (error) {
    await connection.rollback();
    console.error("POST /api/inventory/restore-stock error:", error);
    res.status(500).json({ error: "Server error", details: error.message });
  } finally {
    connection.release();
  }
});

export default router;