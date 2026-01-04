// routes/users.js
import express from "express";
import { pool } from "../db.js";
import jwt from "jsonwebtoken";

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || "secret123";

// auth middleware
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
 * GET /api/users/:user_id/profile
 * - auth required
 * - returns user profile data including shipping address
 * - Nama dari table users, alamat dari table shipping_addresses

Hapus kolom phone dari query SELECT karena kolom tersebut tidak ada di tabel users:
javascript// routes/users.js

/**
 * GET /api/users/:user_id/profile
 * - auth required
 * - returns user profile data including shipping address
 */
router.get("/:user_id/profile", auth, async (req, res) => {
  try {
    const userIdParam = req.params.user_id;
    const tokenUid = req.user?.id || req.user?.email || req.user?.sub;
    
    if (tokenUid && tokenUid.toString() !== userIdParam.toString()) {
      return res.status(403).json({ error: "forbidden" });
    }

    // Get user data (HAPUS 'phone' dari SELECT karena kolom tidak ada)
    const [userRows] = await pool.query(
      "SELECT id, email, display_name, created_at, updated_at FROM users WHERE id = ?",
      [userIdParam]
    );

    if (!userRows || userRows.length === 0) {
      return res.status(404).json({ error: "User not found" });
    }

    const user = userRows[0];

    // Get shipping address (phone ada di sini)
    const [shippingRows] = await pool.query(
      "SELECT full_name, phone, address, city, postal_code, notes FROM shipping_addresses WHERE user_id = ? LIMIT 1",
      [userIdParam]
    );

    const shippingAddress = shippingRows && shippingRows.length > 0 ? {
      fullName: shippingRows[0].full_name ?? "",
      phone: shippingRows[0].phone ?? "",
      address: shippingRows[0].address ?? "",
      city: shippingRows[0].city ?? "",
      postalCode: shippingRows[0].postal_code ?? "",
      notes: shippingRows[0].notes ?? "",
    } : null;

    res.json({
      id: user.id,
      nama: user.display_name ?? "",
      email: user.email ?? "",
      telepon: shippingAddress?.phone ?? "", // Ambil phone dari shipping address
      shippingAddress: shippingAddress,
      created_at: user.created_at,
      updated_at: user.updated_at,
    });
  } catch (err) {
    console.error("GET /api/users/:user_id/profile error:", err);
    res.status(500).json({ error: "server error" });
  }
});

/**
 * PUT /api/users/:user_id/profile
 * - auth required
 * - updates user profile including shipping address
 */
router.put("/:user_id/profile", auth, async (req, res) => {
  const connection = await pool.getConnection();
  
  try {
    const userIdParam = req.params.user_id;
    const tokenUid = req.user?.id || req.user?.email || req.user?.sub;
    
    if (tokenUid && tokenUid.toString() !== userIdParam.toString()) {
      await connection.release();
      return res.status(403).json({ error: "forbidden" });
    }

    const { nama, email, telepon, shippingAddress } = req.body;

    // Basic validation
    if (!nama || !email) {
      await connection.release();
      return res.status(400).json({ error: "nama and email are required" });
    }

    // Email format validation
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(email)) {
      await connection.release();
      return res.status(400).json({ error: "Invalid email format" });
    }

    await connection.beginTransaction();

    // Check if email is already used by another user
    const [existingUsers] = await connection.query(
      "SELECT id FROM users WHERE email = ? AND id != ?",
      [email, userIdParam]
    );

    if (existingUsers.length > 0) {
      await connection.rollback();
      await connection.release();
      return res.status(409).json({ error: "Email already in use" });
    }

    // Update user table (HAPUS phone dari UPDATE karena kolom tidak ada)
    await connection.query(
      "UPDATE users SET display_name = ?, email = ?, updated_at = NOW() WHERE id = ?",
      [nama, email, userIdParam]
    );

    // Update shipping address if provided
    if (shippingAddress) {
      const { fullName, phone, address, city, postalCode, notes } = shippingAddress;

      // Validate required shipping fields
      if (!fullName || !phone || !address || !city || !postalCode) {
        await connection.rollback();
        await connection.release();
        return res.status(400).json({ error: "Shipping address: fullName, phone, address, city, and postalCode are required" });
      }

      // Validate postal code (5 digits)
      if (!/^\d{5}$/.test(postalCode)) {
        await connection.rollback();
        await connection.release();
        return res.status(400).json({ error: "Postal code must be 5 digits" });
      }

      // Validate phone number
      if (phone.length < 10 || !/^[0-9+\-\s]+$/.test(phone)) {
        await connection.rollback();
        await connection.release();
        return res.status(400).json({ error: "Invalid phone number format" });
      }

      // Upsert shipping address
      const shippingQuery = `
        INSERT INTO shipping_addresses (user_id, full_name, phone, address, city, postal_code, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
          full_name = VALUES(full_name),
          phone = VALUES(phone),
          address = VALUES(address),
          city = VALUES(city),
          postal_code = VALUES(postal_code),
          notes = VALUES(notes),
          updated_at = CURRENT_TIMESTAMP
      `;
      
      await connection.query(shippingQuery, [
        userIdParam,
        fullName,
        phone,
        address,
        city,
        postalCode,
        notes || null
      ]);
    }

    await connection.commit();
    await connection.release();

    // Generate new token with updated email if changed
    const token = jwt.sign(
      { id: userIdParam, email, role: req.user.role || 'user' },
      JWT_SECRET,
      { expiresIn: "30d" }
    );

    res.status(200).json({
      ok: true,
      message: "Profile updated successfully",
      token: token,
      user: {
        id: userIdParam,
        nama: nama,
        email: email,
        telepon: telepon || '', // This is just for response, saved in shipping_addresses
      }
    });

  } catch (err) {
    await connection.rollback();
    await connection.release();
    console.error("PUT /api/users/:user_id/profile error:", err);
    res.status(500).json({ error: "server error" });
  }
});
/**
 * GET /api/users/:user_id/shipping
 * - auth required
 * - returns shipping address only (alamat pengiriman)
 */
router.get("/:user_id/shipping", auth, async (req, res) => {
  try {
    const userIdParam = req.params.user_id;
    const tokenUid = req.user?.id || req.user?.email || req.user?.sub;
    
    if (tokenUid && tokenUid.toString() !== userIdParam.toString()) {
      return res.status(403).json({ error: "forbidden" });
    }

    const [rows] = await pool.query(
      "SELECT full_name, phone, address, city, postal_code, notes, created_at, updated_at FROM shipping_addresses WHERE user_id = ? LIMIT 1",
      [userIdParam]
    );
    
    if (!rows || rows.length === 0) {
      return res.status(404).json({ error: "not found" });
    }
    
    const r = rows[0];
    res.json({
      fullName: r.full_name ?? "",
      phone: r.phone ?? "",
      address: r.address ?? "",
      city: r.city ?? "",
      postalCode: r.postal_code ?? "",
      notes: r.notes ?? "",
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    });
  } catch (err) {
    console.error("GET /api/users/:user_id/shipping error:", err);
    res.status(500).json({ error: "server error" });
  }
});

/**
 * PUT /api/users/:user_id/shipping
 * - auth required
 * - upsert shipping address only (update hanya alamat pengiriman)
 */
router.put("/:user_id/shipping", auth, async (req, res) => {
  try {
    const userIdParam = req.params.user_id;
    const tokenUid = req.user?.id || req.user?.email || req.user?.sub;
    
    if (tokenUid && tokenUid.toString() !== userIdParam.toString()) {
      return res.status(403).json({ error: "forbidden" });
    }
    
    const { fullName, phone, address, city, postalCode, notes } = req.body;
    
    if (!fullName || !phone || !address || !city || !postalCode) {
      return res.status(400).json({ error: "missing required fields" });
    }
    
    const q = `
      INSERT INTO shipping_addresses (user_id, full_name, phone, address, city, postal_code, notes)
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        full_name = VALUES(full_name),
        phone = VALUES(phone),
        address = VALUES(address),
        city = VALUES(city),
        postal_code = VALUES(postal_code),
        notes = VALUES(notes),
        updated_at = CURRENT_TIMESTAMP
    `;
    
    await pool.query(q, [userIdParam, fullName, phone, address, city, postalCode, notes ?? null]);
    res.status(200).json({ ok: true, message: "Shipping address updated" });
  } catch (err) {
    console.error("PUT /api/users/:user_id/shipping error:", err);
    res.status(500).json({ error: "server error" });
  }
});

export default router;