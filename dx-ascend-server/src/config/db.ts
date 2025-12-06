import Database from "better-sqlite3";
import { config } from "./env";

let db: Database.Database | null = null;

export function getDb(): Database.Database {
  if (!db) {
    db = new Database(config.dbPath);
    db.pragma("journal_mode = WAL");
  }
  return db;
}
