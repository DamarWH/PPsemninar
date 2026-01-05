export const pool = mysql.createPool({
  host: '127.0.0.1',           // Changed from process.env.DB_HOST
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  port: 3306,

  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// Add this debug line right after the pool creation
console.log('🔍 DB Config:', {
  host: '127.0.0.1',
  user: process.env.DB_USER,
  database: process.env.DB_NAME,
  port: 3306
});