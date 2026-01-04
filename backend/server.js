// server.js
import express from "express";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import cors from "cors";
import os from "os";
import jwt from "jsonwebtoken";

import authRoutes from "./routes/auth.js";
import productRoutes from "./routes/products.js";
import cartRoutes from "./routes/keranjang.js";
import userRoutes from "./routes/users.js"; 
import orderRoutes from "./routes/orders.js";
import inventoryRoutes from './routes/inventory.js';  // 🔥 TAMBAHKAN INI

// admin routes
import adminProductsRoutes from "./routes/admin_products.js";
import adminOrdersRoutes from "./routes/admin_orders.js";
import adminUploadRoutes from "./routes/admin_uploads.js";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// middlewares
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

// simple request logger for debugging
app.use((req, res, next) => {
  console.log(new Date().toISOString(), req.method, req.url, "from", req.ip);
  next();
});

// serve uploads directory
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// routes (non-admin)
app.use("/api/auth", authRoutes);
app.use("/api/products", productRoutes);
app.use("/api/cart", cartRoutes);
app.use("/api/users", userRoutes);
app.use("/api/orders", orderRoutes);
app.use('/api/inventory', inventoryRoutes); // 🔥 TAMBAHKAN INI

// admin routes
app.use("/api/admin/products", adminProductsRoutes);
app.use("/api/admin/orders", adminOrdersRoutes);
app.use("/api/admin/upload", adminUploadRoutes);

// simple root
app.get("/", (req, res) => res.json({ ok: true, message: "BatikSekarniti API" }));

// helper: get local IPv4 address
function getLocalIP() {
  const interfaces = os.networkInterfaces();
  for (const name in interfaces) {
    for (const iface of interfaces[name]) {
      if (iface.family === "IPv4" && !iface.internal) {
        return iface.address;
      }
    }
  }
  return "127.0.0.1";
}

// Verify token endpoint
app.get("/api/auth/verify-token", (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) return res.status(401).json({ error: "Unauthorized" });

  const token = authHeader.split(" ")[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    return res.json({ valid: true, user: decoded });
  } catch (err) {
    return res.status(401).json({ error: "Token invalid" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, "0.0.0.0", () => {
  const localIP = getLocalIP();
  console.log(`🚀 Server running on http://0.0.0.0:${PORT}`);
  console.log(`🌐 Server Local IP: http://${localIP}:${PORT}`);
  console.log(`📦 Cart API: http://${localIP}:${PORT}/api/cart`);
  console.log(`👤 Users API: http://${localIP}:${PORT}/api/users`); // 🔥 TAMBAHKAN INI
});