// routes/admin_uploads.js
import express from "express";
import multer from "multer";
import { authMiddleware, adminOnly } from "../middleware/auth.js";
import { uploadSingle } from "../controllers/uploadController.js";

const router = express.Router();
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, "uploads/"),
  filename: (req, file, cb) => cb(null, `${Date.now()}_${file.originalname.replace(/\s+/g, "_")}`),
});
const upload = multer({ storage });

router.post("/image", authMiddleware, adminOnly, upload.single("file"), uploadSingle);

export default router;