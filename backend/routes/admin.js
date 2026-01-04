// make_admin.js
import mysql from "mysql2/promise";
import bcrypt from "bcrypt";
import dotenv from "dotenv";
dotenv.config();

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME
});

async function run() {
  const email = process.argv[2];
  const password = process.argv[3];
  const name = process.argv[4] || 'Admin';

  if (!email || !password) {
    console.log("Usage: node make_admin.js email password [display_name]");
    process.exit(1);
  }

  const hash = await bcrypt.hash(password, 10);
  const [res] = await pool.query(
    "INSERT INTO users (email,password,display_name,role) VALUES (?,?,?,?)",
    [email, hash, name, 'admin']
  );

  console.log("Admin created with id:", res.insertId);
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });