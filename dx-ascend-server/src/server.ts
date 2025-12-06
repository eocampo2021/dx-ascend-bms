import http from "http";
import app from "./app";
import { config } from "./config/env";
import { initDb } from "./db/initdb";

async function main() {
  initDb();

  const server = http.createServer(app);

  server.listen(config.port, () => {
    console.log(
      `🚀 DX-Ascend Server listening on http://localhost:${config.port}`
    );
  });
}

main();
