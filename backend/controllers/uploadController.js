// controllers/uploadController.js
import path from "path";
import fs from "fs";

export function uploadSingle(req, res) {
  try {
    if (!req.file) return res.status(400).json({ error: "No file uploaded" });
    const url = `${req.protocol}://${req.hostname}:${process.env.PORT || 3000}/uploads/${req.file.filename}`;
    return res.json({ url });
  } catch (e) {
    console.error("uploadSingle:", e);
    return res.status(500).json({ error: "Upload error" });
  }
}