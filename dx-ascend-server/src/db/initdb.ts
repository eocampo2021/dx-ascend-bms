import { getDb } from "../config/db";
import * as fs from "fs";
import * as path from "path";

export function initDb() {
  const db = getDb();
  const schemaPath = path.join(__dirname, "schema.sql");
  const sql = fs.readFileSync(schemaPath, "utf-8");
  db.exec("PRAGMA foreign_keys = ON;");
  db.exec(sql);
  console.log("✅ Database initialized");
}

if (require.main === module) {
  initDb();
}
