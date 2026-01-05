// controllers/productController.js
import { pool } from "../db.js";
import fs from "fs";
import path from "path";

const uploadsBaseUrl = (req) => {
  // if you serve static at /uploads
  const host = req.hostname || "https://api.damargtg.store/api";
  const port = process.env.PORT || 3000;
  return `${req.protocol}://${host}:${port}/uploads`;
};

export async function getAllProducts(req, res) {
  try {
    const [rows] = await pool.query("SELECT * FROM products ORDER BY created_at DESC");
    // parse JSON size_stock to object
    const products = rows.map((r) => ({ ...r, size_stock: r.size_stock ? JSON.parse(r.size_stock) : {} }));
    res.json(products);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
}

export async function getProductById(req, res) {
  try {
    const id = req.params.id;
    const [rows] = await pool.query("SELECT * FROM products WHERE id = ?", [id]);
    if (!rows.length) return res.status(404).json({ error: "Product not found" });
    const product = rows[0];
    if (product.size_stock) product.size_stock = JSON.parse(product.size_stock);
    // images
    const [imgs] = await pool.query("SELECT url FROM product_images WHERE product_id = ? ORDER BY `order` ASC", [id]);
    product.fotos = imgs.map(i => i.url);
    res.json(product);
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
}

export async function createProduct(req, res) {
  // fields in req.body, files in req.files
  try {
    const {
      nama,
      harga,
      kategori,
      warna,
      deskripsi,
      size_stock // expected as JSON string or object
    } = req.body;

    const parsedSizeStock = typeof size_stock === "string" && size_stock ? JSON.parse(size_stock) : (size_stock || {});
    const totalStock = Object.values(parsedSizeStock).reduce((a,b)=>a+ (Number(b)||0), 0);

    // main foto: first file if provided
    let mainFoto = null;
    const fileUrls = [];
    if (req.files && req.files.length) {
      for (const f of req.files) {
        const url = `${req.protocol}://${req.hostname}:${process.env.PORT || 3000}/uploads/${f.filename}`;
        fileUrls.push(url);
      }
      mainFoto = fileUrls[0];
    }

    const [result] = await pool.query(
      `INSERT INTO products (nama,harga,kategori,warna,deskripsi,stok,size_stock,foto,created_at) VALUES (?,?,?,?,?,?,?,?,NOW())`,
      [nama, Number(harga)||0, kategori, warna, deskripsi, totalStock, JSON.stringify(parsedSizeStock), mainFoto]
    );
    const productId = result.insertId;

    // save images to product_images
    if (fileUrls.length) {
      const insertImages = fileUrls.map((u, idx) => [productId, u, idx]);
      await pool.query("INSERT INTO product_images (product_id, url, `order`) VALUES ?", [insertImages]);
    }

    res.status(201).json({ message: "Product created", id: productId });
  } catch (e) {
    console.error("createProduct:", e);
    res.status(500).json({ error: "Server error" });
  }
}

export async function updateProduct(req, res) {
  try {
    const id = req.params.id;
    // check exist
    const [existing] = await pool.query("SELECT * FROM products WHERE id = ?", [id]);
    if (!existing.length) return res.status(404).json({ error: "Product not found" });

    const {
      nama, harga, kategori, warna, deskripsi, size_stock, remove_image_urls // optional field with list to remove
    } = req.body;

    const parsedSizeStock = size_stock ? (typeof size_stock === "string" ? JSON.parse(size_stock) : size_stock) : null;
    const totalStock = parsedSizeStock ? Object.values(parsedSizeStock).reduce((a,b)=>a + (Number(b)||0), 0) : null;

    // handle new uploaded files
    const fileUrls = [];
    if (req.files && req.files.length) {
      for (const f of req.files) {
        const url = `${req.protocol}://${req.hostname}:${process.env.PORT || 3000}/uploads/${f.filename}`;
        fileUrls.push(url);
      }
    }

    // build update
    const updates = [];
    const params = [];
    if (nama) { updates.push("nama=?"); params.push(nama); }
    if (harga) { updates.push("harga=?"); params.push(Number(harga)); }
    if (kategori) { updates.push("kategori=?"); params.push(kategori); }
    if (warna) { updates.push("warna=?"); params.push(warna); }
    if (deskripsi) { updates.push("deskripsi=?"); params.push(deskripsi); }
    if (parsedSizeStock) { updates.push("size_stock=?"); params.push(JSON.stringify(parsedSizeStock)); updates.push("stok=?"); params.push(totalStock); }
    if (fileUrls.length) {
      updates.push("foto=?");
      params.push(fileUrls[0]);
    }
    if (updates.length === 0) {
      return res.status(400).json({ error: "No fields to update" });
    }
    updates.push("updated_at=NOW()");

    params.push(id);
    const sql = `UPDATE products SET ${updates.join(", ")} WHERE id = ?`;
    await pool.query(sql, params);

    // insert new images to product_images
    if (fileUrls.length) {
      const insertImages = fileUrls.map((u, idx) => [id, u, idx]);
      await pool.query("INSERT INTO product_images (product_id, url, `order`) VALUES ?", [insertImages]);
    }

    // remove images if requested (remove_image_urls expected as JSON array of urls)
    if (remove_image_urls) {
      let toRemove = remove_image_urls;
      if (typeof remove_image_urls === "string") {
        try { toRemove = JSON.parse(remove_image_urls); } catch(e){ toRemove = []; }
      }
      if (Array.isArray(toRemove) && toRemove.length) {
        await pool.query("DELETE FROM product_images WHERE product_id = ? AND url IN (?)", [id, toRemove]);
        // optionally also unlink files from disk if they are local uploads: parse the filename from URL and fs.unlink
        toRemove.forEach(url => {
          try {
            const fileName = url.split("/uploads/")[1];
            if (fileName) {
              const filePath = path.join(process.cwd(), "uploads", fileName);
              if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
            }
          } catch (e) {}
        });
      }
    }

    res.json({ message: "Product updated" });
  } catch (e) {
    console.error("updateProduct:", e);
    res.status(500).json({ error: "Server error" });
  }
}

export async function deleteProduct(req, res) {
  try {
    const id = req.params.id;
    // delete images records first to get urls to delete files
    const [imgs] = await pool.query("SELECT url FROM product_images WHERE product_id = ?", [id]);
    await pool.query("DELETE FROM product_images WHERE product_id = ?", [id]);
    await pool.query("DELETE FROM products WHERE id = ?", [id]);

    // delete uploaded files locally if exist
    imgs.forEach(img => {
      try {
        const fileName = img.url.split("/uploads/")[1];
        if (fileName) {
          const filePath = path.join(process.cwd(), "uploads", fileName);
          if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
        }
      } catch (e) {}
    });

    res.json({ message: "Product deleted" });
  } catch (e) {
    console.error("deleteProduct:", e);
    res.status(500).json({ error: "Server error" });
  }
}