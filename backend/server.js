
  import express from "express";
  import dotenv from "dotenv";
  import path from "path";
  import { fileURLToPath } from "url";
  import cors from "cors";
  import os from "os";
  import jwt from "jsonwebtoken";
  import mysql from "mysql2/promise";


  import authRoutes from "./routes/auth.js";
  import productRoutes from "./routes/products.js";
  import cartRoutes from "./routes/keranjang.js";
  import userRoutes from "./routes/users.js"; 
  import orderRoutes from "./routes/orders.js";
  import inventoryRoutes from './routes/inventory.js';

  // admin routes
  import adminRoutes from "./routes/admin.js";  // 🔥 TAMBAHKAN INI - ADMIN MANAGEMENT
  import adminProductsRoutes from "./routes/admin_products.js";
  import adminOrdersRoutes from "./routes/admin_orders.js";
  import adminUploadRoutes from "./routes/admin_uploads.js";

  dotenv.config();

  const __filename = fileURLToPath(import.meta.url);
  const __dirname = path.dirname(__filename);

  const app = express();

  // ============================================
  // MIDDLEWARE - ORDER MATTERS!
  // ============================================

  // 1. CORS must be first
  app.use(cors({
    origin: '*', // For development - restrict in production
    credentials: true
  }));

  // 2. Body parsers with larger limits for file uploads
  app.use(express.json({ limit: '50mb' }));
  app.use(express.urlencoded({ extended: true, limit: '50mb' }));

  // 3. Request logger for debugging
  app.use((req, res, next) => {
    console.log(new Date().toISOString(), req.method, req.url, "from", req.ip);
    next();
  });

  // ============================================
  // STATIC FILES
  // ============================================

  // Serve uploads directory
  app.use("/uploads", express.static(path.join(__dirname, "uploads")));

  // ============================================
  // API ROUTES
  // ============================================

  // Root endpoint
  app.get("/", (req, res) => {
    res.json({ 
      ok: true, 
      message: "BatikSekarniti API",
      version: "1.0.0",
      timestamp: new Date().toISOString()
    });
  });

  // Auth routes (public)
  app.use("/auth", authRoutes);

  // User routes
  app.use("/products", productRoutes);
  app.use("/cart", cartRoutes);
  app.use("/users", userRoutes);
  app.use("/orders", orderRoutes);
  app.use('/inventory', inventoryRoutes);

  // Admin routes
  app.use("/admin", adminRoutes);  // 🔥 ADMIN MANAGEMENT (kelola admin)
  app.use("/admin/products", adminProductsRoutes);
  app.use("/admin/orders", adminOrdersRoutes);
  app.use("/admin/upload", adminUploadRoutes);

  // ============================================
  // LEGACY TOKEN VERIFICATION (for backward compatibility)
  // ============================================

  app.get("/auth/verify-token", (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const token = authHeader.split(" ")[1];
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET || "secret123");
      return res.json({ 
        valid: true, 
        user: {
          id: Number(decoded.id),
          email: decoded.email,
          role: decoded.role
        }
      });
    } catch (err) {
      return res.status(401).json({ error: "Token invalid" });
    }
  });

  // ============================================
  // ERROR HANDLING
  // ============================================

  // 404 handler for undefined routes
  app.use((req, res) => {
    console.log(`❌ 404 Not Found: ${req.method} ${req.path}`);
    res.status(404).json({ 
      error: 'Not Found',
      path: req.path,
      method: req.method,
      message: 'The requested endpoint does not exist'
    });
  });

  // Global error handler - MUST send JSON, never HTML
  app.use((err, req, res, next) => {
    console.error('❌ Global error handler caught:', err);
    console.error('Stack trace:', err.stack);
    
    // Always send JSON, never HTML error pages
    res.status(err.status || 500).json({
      error: 'Server Error',
      message: err.message,
      ...(process.env.NODE_ENV === 'development' && { 
        stack: err.stack,
        details: err 
      })
    });
  });

  // ============================================
  // HELPER FUNCTIONS
  // ============================================

  // Get local IPv4 address
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

  // ============================================
  // START SERVER
  // ============================================

  const PORT = process.env.PORT || 3000;

  app.listen(PORT, "0.0.0.0", () => {
    const localIP = getLocalIP();
    
    console.log("=".repeat(60));
    console.log("🚀 BatikSekarniti API Server Started");
    console.log("=".repeat(60));
    console.log(`📍 Server running on: http://0.0.0.0:${PORT}`);
    console.log(`🌐 Local IP: http://${localIP}:${PORT}`);
    console.log(`🔒 Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log("=".repeat(60));
    console.log("📡 Available Endpoints:");
    console.log(`  Auth:      ${localIP}:${PORT}/auth/*`);
    console.log(`  Products:  ${localIP}:${PORT}/products`);
    console.log(`  Cart:      ${localIP}:${PORT}/cart`);
    console.log(`  Users:     ${localIP}:${PORT}/users`);
    console.log(`  Orders:    ${localIP}:${PORT}/orders`);
    console.log(`  Inventory: ${localIP}:${PORT}/inventory`);
    console.log("=".repeat(60));
    console.log("🔐 Admin Endpoints:");
    console.log(`  Admin Mgmt:    ${localIP}:${PORT}/admin/*`);
    console.log(`  Admin Products: ${localIP}:${PORT}/admin/products`);
    console.log(`  Admin Orders:   ${localIP}:${PORT}/admin/orders`);
    console.log(`  Admin Upload:   ${localIP}:${PORT}/admin/upload`);
    console.log("=".repeat(60));
    console.log("✅ Server ready to accept connections");
    console.log("=".repeat(60));
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('⚠️ SIGTERM signal received: closing HTTP server');
    app.close(() => {
      console.log('✅ HTTP server closed');
      process.exit(0);
    });
  });

  process.on('SIGINT', () => {
    console.log('\n⚠️ SIGINT signal received: closing HTTP server');
    process.exit(0);
  });

  // Handle uncaught exceptions
  process.on('uncaughtException', (err) => {
    console.error('❌ UNCAUGHT EXCEPTION:', err);
    console.error('Stack:', err.stack);
    process.exit(1);
  });

  process.on('unhandledRejection', (reason, promise) => {
    console.error('❌ UNHANDLED REJECTION at:', promise);
    console.error('Reason:', reason);
  });
export const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "nodepp",
  password: process.env.DB_PASS || "",
  database: process.env.DB_NAME || "batiksekarniti",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});
  export default app;