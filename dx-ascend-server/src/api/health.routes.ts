import { Router, Request, Response } from "express";
import { getDb } from "../config/db";

const router = Router();

router.get("/health", (req: Request, res: Response) => {
  const db = getDb();
  const row = db.prepare("SELECT name FROM sqlite_master WHERE type='table' LIMIT 1").get();
  res.json({
    status: "ok",
    dbTableSample: row?.name ?? null,
    ts: new Date().toISOString(),
  });
});

export default router;
