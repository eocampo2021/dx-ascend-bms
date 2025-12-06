import express from "express";
import cors from "cors";
import path from "path";
import apiRouter from "./api";

const app = express();

app.use(cors());
app.use(express.json());

// Carpeta de archivos estáticos (HTML, JS, CSS)
const publicDir = path.join(__dirname, "..", "public");
app.use(express.static(publicDir));

// Ruta “linda” para ver una pantalla: /runtime/1, /runtime/2, etc.
app.get("/runtime/:screenId", (req, res) => {
  res.sendFile(path.join(publicDir, "runtime.html"));
});

app.use("/api", apiRouter);

app.get("/", (req, res) => {
  res.send("DX-Ascend Server v0.1 – API en /api");
});

export default app;
