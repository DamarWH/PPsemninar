// db.js
import mysql from "mysql2/promise";
import dotenv from "dotenv";
dotenv.config();

export const pool = mysql.createPool({
  host: process.env.DB_HOST,       // 127.0.0.1
  user: process.env.DB_USER,       // batikapp
  password: process.env.DB_PASS,   // password kamu
  database: process.env.DB_NAME,   // batiksekarniti
  port: 3306,

  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// TEST KONEKSI SEKALI SAJA
(async () => {
  try {
    const conn = await pool.getConnection();
    console.log("✅ MySQL Connected SUCCESSFULLY");
    conn.release();
  } catch (err) {
    console.error("❌ MySQL Connection FAILED:", err.message);
    process.exit(1);
  }
})();