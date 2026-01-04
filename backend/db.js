// db.js
import mysql from "mysql2/promise";
import os from "os";
import dotenv from "dotenv";
dotenv.config();

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

export const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  user: process.env.DB_USER || "nodepp",
  password: process.env.DB_PASS || "",
  database: process.env.DB_NAME || "batiksekarniti",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

(async () => {
  try {
    const connection = await pool.getConnection();
    connection.release();
    const localIP = getLocalIP();
    console.log(`✅ MySQL Connected as '${process.env.DB_USER || "nodepp"}'`);
    console.log(`🌐 Server Local IP: ${localIP}`);
    console.log(`📡 Koneksi Database: mysql://${localIP}/${process.env.DB_NAME || "batiksekarniti"}`);
  } catch (err) {
    console.error("❌ MySQL Connection Error:", err);
    process.exit(1);
  }
})();