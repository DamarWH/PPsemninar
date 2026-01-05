// make_admin.js
import mysql from "mysql2/promise";
import bcrypt from "bcrypt";
import dotenv from "dotenv";
dotenv.config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || "https://damargtg.store",
  user: process.env.DB_USER || "nodepp",
  password: process.env.DB_PASS || "",
  database: process.env.DB_NAME || "batiksekarniti"
});

async function createAdmin() {
  const email = "a@a.com";
  const password = "123456";
  const display_name = "Admin Utama";
  const role = "admin";

  try {
    const hash = await bcrypt.hash(password, 10);

    const [existing] = await pool.query(
      "SELECT * FROM users WHERE email = ?",
      [email]
    );

    if (existing.length > 0) {
      console.log(`⚠️ User dengan email ${email} sudah ada.`);
      return;
    }

    const [result] = await pool.query(
      "INSERT INTO users (email, password, display_name, role) VALUES (?, ?, ?, ?)",
      [email, hash, display_name, role]
    );

    console.log("✅ Admin berhasil dibuat!");
    console.log("🆔 ID:", result.insertId);
    console.log("📧 Email:", email);
    console.log("🔑 Password:", password);
    console.log("🎭 Role:", role);

    process.exit(0);
  } catch (err) {
    console.error("❌ Error membuat admin:", err);
    process.exit(1);
  }
}

createAdmin();