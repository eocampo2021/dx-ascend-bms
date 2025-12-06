export const config = {
  port: parseInt(process.env.ASCEND_PORT || "4000", 10),
  dbPath: process.env.ASCEND_DB_PATH || "ascend.db",
};
