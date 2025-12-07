import Database from "better-sqlite3";
import { config } from "./env";

let db: any = null;

export function getDb(): any {
  if (!db) {
    db = new Database(config.dbPath);
    db.pragma("journal_mode = WAL");
  }
  return db;
}
