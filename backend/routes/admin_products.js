// routes/admin_products.js
import express from "express";
import multer from "multer";
import { authMiddleware, adminOnly } from "../middleware/auth.js";
import {
  getAllProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct
} from "../controllers/productController.js";

const router = express.Router();

// Multer config: store file in /uploads with original filename prefixed
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, "uploads/"),
  filename: (req, file, cb) => {
    const name = `${Date.now()}_${file.originalname.replace(/\s+/g, "_")}`;
    cb(null, name);
  },
});
const upload = multer({ storage });

// protect all admin routes
router.use(authMiddleware, adminOnly);

router.get("/", getAllProducts);
router.get("/:id", getProductById);
router.post("/", upload.array("files"), createProduct);
router.put("/:id", upload.array("files"), updateProduct);
router.delete("/:id", deleteProduct);

export default router;