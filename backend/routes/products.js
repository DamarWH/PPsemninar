// backend/routes/products.js
import express from "express";
import { pool } from "../db.js";
import multer from "multer";
import fs from "fs";
import path from "path";
import jwt from "jsonwebtoken";

const router = express.Router();
const JWT_SECRET = process.env.JWT_SECRET || "secret123";

// simple auth middleware (JWT)
const auth = (req, res, next) => {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) return res.status(401).json({ error: "No token" });
  const token = authHeader.split(" ")[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    next();
  } catch (e) {
    return res.status(401).json({ error: "Invalid token" });
  }
};

// multer setup (keperluan upload image)
const uploadsDir = path.join(process.cwd(), "uploads");
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir);
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadsDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const name = `${Date.now()}-${Math.round(Math.random()*1e9)}${ext}`;
    cb(null, name);
  }
});
const upload = multer({ storage });

// list produk (with images) — tolerant terhadap nama kolom image di DB
router.get("/", async (req, res) => {
  try {
    // ambil produk
    const [products] = await pool.query(`
      SELECT p.*, c.name AS category_name
      FROM products p
      LEFT JOIN categories c ON p.category_id = c.id
      ORDER BY p.created_at DESC
    `);

    // ambil images — gunakan SELECT * supaya tidak error jika nama kolom beda
    for (const p of products) {
      try {
        const [imgs] = await pool.query("SELECT * FROM product_images WHERE product_id = ?", [p.id]);

        // normalisasi fields gambar: cari properti image_url/url/path/image (fallback ke uploads)
        const mapped = (imgs || []).map((im) => {
          // im mungkin RowDataPacket dengan kolom yang ada
          const imgObj = { ...im };
          // normalisasi primary flag
          const isPrimary = imgObj.is_primary == 1 || imgObj.is_primary === true || imgObj.primary == 1;
          // determine url candidates
          const urlCandidate =
            imgObj.image_url ||
            imgObj.url ||
            imgObj.path ||
            imgObj.image ||
            imgObj.file ||
            (imgObj.filename ? `/uploads/${imgObj.filename}` : null) ||
            null;

          return {
            id: imgObj.id,
            image_url: urlCandidate,
            is_primary: isPrimary,
            raw: imgObj, // keep original row for debugging if needed
          };
        });

        p.images = mapped;
      } catch (imgErr) {
        // kalau query gambar error (mis. tabel tidak ada) jangan crash seluruh endpoint
        console.error("products.get -> failed to read product_images for product", p.id, imgErr);
        p.images = [];
      }
    }

    res.json(products);
  } catch (err) {
    console.error("products.get ->", err);
    res.status(500).json({ error: "server error" });
  }
});

// create product (admin)
router.post("/", auth, upload.array("files", 10), async (req, res) => {
  try {
    if (req.user.role !== "admin") return res.status(403).json({ error: "Forbidden" });

    // gather fields (sesuaikan nama field yang kamu kirim dari client)
    const { name, nama, price, harga, material, kategori, category_id, color, warna, description, deskripsi, stock, stok, size_stock } = req.body;

    // support both english and indonesian field names
    const finalName = name || nama || null;
    const finalPrice = price || harga || 0;
    const finalMaterial = material || null;
    const finalCategoryId = category_id || null;
    const finalColor = color || warna || null;
    const finalDescription = description || deskripsi || null;
    const finalStock = stock || stok || 0;
    const finalSizeStock = size_stock || null;

    // insert into products (sesuaikan kolom produk di DB-mu)
    const [result] = await pool.query(
      "INSERT INTO products (nama, harga, kategori, warna, deskripsi, stok, size_stock, foto, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())",
      [
        finalName,
        finalPrice,
        kategori || null,
        finalColor,
        finalDescription,
        finalStock,
        finalSizeStock ? finalSizeStock : null,
        null, // foto utama (kita isi setelah upload image jika ada)
      ]
    );

    const newId = result.insertId;

    // simpan file upload ke tabel product_images jika ada
    if (req.files && req.files.length) {
      for (const f of req.files) {
        const url = `/uploads/${f.filename}`;
        try {
          const [r] = await pool.query("INSERT INTO product_images (product_id, image_url, is_primary, filename) VALUES (?, ?, ?, ?)",
            [newId, url, 0, f.filename]
          );
          // optionally mark first as primary
        } catch (e) {
          console.error("failed to insert product_images row", e);
        }
      }
      // update foto utama di products (ambil first uploaded)
      const firstUrl = `/uploads/${req.files[0].filename}`;
      try {
        await pool.query("UPDATE products SET foto = ? WHERE id = ?", [firstUrl, newId]);
      } catch (e) {
        console.error("failed to update products.foto", e);
      }
    }

    const [rows] = await pool.query("SELECT * FROM products WHERE id = ?", [newId]);
    res.status(201).json(rows[0]);
  } catch (err) {
    console.error("products.post ->", err);
    res.status(500).json({ error: "server error" });
  }
});

// upload images for a product (separate endpoint)
router.post("/:id/images", auth, upload.array("images", 10), async (req, res) => {
  try {
    if (req.user.role !== "admin") return res.status(403).json({ error: "Forbidden" });
    const productId = req.params.id;
    if (!req.files || !req.files.length) return res.status(400).json({ error: "No files" });

    const inserted = [];
    for (const f of req.files) {
      const url = `/uploads/${f.filename}`; // public path
      try {
        const [r] = await pool.query("INSERT INTO product_images (product_id, image_url, is_primary, filename) VALUES (?, ?, ?, ?)", [productId, url, 0, f.filename]);
        inserted.push({ id: r.insertId, image_url: url });
      } catch (e) {
        console.error("product images insert error:", e);
      }
    }
    res.status(201).json({ uploaded: inserted });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "server error" });
  }
});

// update product (admin)
router.put("/:id", auth, async (req, res) => {
  try {
    if (req.user.role !== "admin") return res.status(403).json({ error: "Forbidden" });
    const pid = req.params.id;
    const { name, nama, price, harga, material, category_id, color, warna, description, deskripsi, stock, stok } = req.body;

    const finalName = name || nama || null;
    const finalPrice = price || harga || 0;
    const finalColor = color || warna || null;
    const finalDescription = description || deskripsi || null;
    const finalStock = stock || stok || 0;

    await pool.query(
      `UPDATE products SET nama=?, harga=?, warna=?, category_id=?, deskripsi=?, stok=?, updated_at=NOW() WHERE id=?`,
      [finalName, finalPrice, finalColor, category_id || null, finalDescription, finalStock, pid]
    );
    const [rows] = await pool.query("SELECT * FROM products WHERE id=?", [pid]);
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "server error" });
  }
});

// delete product (admin)
router.delete("/:id", auth, async (req, res) => {
  try {
    if (req.user.role !== "admin") return res.status(403).json({ error: "Forbidden" });
    const pid = req.params.id;
    // optionally remove images from disk
    const [imgs] = await pool.query("SELECT * FROM product_images WHERE product_id = ?", [pid]);
    for (const im of imgs) {
      // try to delete actual file if available
      const filename = im.filename || (im.image_url ? im.image_url.replace('/uploads/', '') : null);
      if (filename) {
        const filePath = path.join(process.cwd(), 'uploads', filename);
        if (fs.existsSync(filePath)) {
          try { fs.unlinkSync(filePath); } catch (e) { console.warn("unlink failed", e); }
        }
      }
    }
    await pool.query("DELETE FROM product_images WHERE product_id = ?", [pid]);
    await pool.query("DELETE FROM products WHERE id = ?", [pid]);
    res.json({ ok: true });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "server error" });
  }
});

export default router;