import { Router, Request, Response } from "express";
import { getDb } from "../config/db";

const router = Router();

// Screens
router.get("/screens", (req: Request, res: Response) => {
  const db = getDb();
  const rows = db
    .prepare(
      "SELECT id, name, route, description, enabled FROM screens ORDER BY id"
    )
    .all();
  res.json(rows);
});

router.post("/screens", (req: Request, res: Response) => {
  const { name, route, description, enabled } = req.body;

  if (!name || !route) {
    return res
      .status(400)
      .json({ error: "name y route son obligatorios para la pantalla" });
  }

  const db = getDb();

  try {
    const stmt = db.prepare(
      `INSERT INTO screens (name, route, description, enabled)
       VALUES (@name, @route, @description, @enabled)`
    );

    const info = stmt.run({
      name,
      route,
      description: description ?? null,
      enabled: enabled === undefined ? 1 : enabled ? 1 : 0,
    });

    const row = db
      .prepare(
        "SELECT id, name, route, description, enabled FROM screens WHERE id = ?"
      )
      .get(info.lastInsertRowid);

    res.status(201).json(row);
  } catch (e) {
    const msg = (e as Error).message;
    res.status(400).json({ error: msg });
  }
});

router.put("/screens/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const { name, route, description, enabled } = req.body;
  if (!name || !route) {
    return res
      .status(400)
      .json({ error: "name y route son obligatorios para la pantalla" });
  }

  const db = getDb();

  const existing = db
    .prepare("SELECT id FROM screens WHERE id = ?")
    .get(id);
  if (!existing) {
    return res.status(404).json({ error: "pantalla no encontrada" });
  }

  try {
    const stmt = db.prepare(
      `UPDATE screens
       SET name = @name,
           route = @route,
           description = @description,
           enabled = @enabled
       WHERE id = @id`
    );

    stmt.run({
      id,
      name,
      route,
      description: description ?? null,
      enabled: enabled === undefined ? 1 : enabled ? 1 : 0,
    });

    const row = db
      .prepare(
        "SELECT id, name, route, description, enabled FROM screens WHERE id = ?"
      )
      .get(id);

    res.json(row);
  } catch (e) {
    const msg = (e as Error).message;
    res.status(400).json({ error: msg });
  }
});

router.delete("/screens/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const db = getDb();
  const info = db.prepare("DELETE FROM screens WHERE id = ?").run(id);

  if (info.changes === 0) {
    return res.status(404).json({ error: "pantalla no encontrada" });
  }

  res.status(204).send();
});

// Widgets for a screen
router.get("/screens/:id/widgets", (req: Request, res: Response) => {
  const screenId = Number(req.params.id);
  if (!Number.isFinite(screenId)) {
    return res.status(400).json({ error: "screen id inválido" });
  }

  const db = getDb();

  const screen = db
    .prepare("SELECT id FROM screens WHERE id = ?")
    .get(screenId);
  if (!screen) {
    return res.status(404).json({ error: "pantalla no encontrada" });
  }

  const rows = db
    .prepare(
      `SELECT id, screen_id, type, name, x, y, width, height, config_json
       FROM widgets
       WHERE screen_id = ?
       ORDER BY id`
    )
    .all(screenId);

  const result = rows.map((w: any) => ({
    ...w,
    config_json: safeParseJson(w.config_json),
  }));

  res.json(result);
});

router.post("/screens/:id/widgets", (req: Request, res: Response) => {
  const screenId = Number(req.params.id);
  if (!Number.isFinite(screenId)) {
    return res.status(400).json({ error: "screen id inválido" });
  }

  const { type, name, x, y, width, height, config_json } = req.body;
  if (!type || !name) {
    return res
      .status(400)
      .json({ error: "type y name son obligatorios para el widget" });
  }

  const db = getDb();

  const screen = db
    .prepare("SELECT id FROM screens WHERE id = ?")
    .get(screenId);
  if (!screen) {
    return res.status(400).json({ error: "screen_id no existe" });
  }

  const cfgText =
    config_json === undefined || config_json === null
      ? "{}"
      : JSON.stringify(config_json);

  const stmt = db.prepare(
    `INSERT INTO widgets
     (screen_id, type, name, x, y, width, height, config_json)
     VALUES
     (@screen_id, @type, @name, @x, @y, @width, @height, @config_json)`
  );

  const info = stmt.run({
    screen_id: screenId,
    type,
    name,
    x: x ?? 0,
    y: y ?? 0,
    width: width ?? 100,
    height: height ?? 100,
    config_json: cfgText,
  });

  const row = db
    .prepare(
      `SELECT id, screen_id, type, name, x, y, width, height, config_json
       FROM widgets
       WHERE id = ?`
    )
    .get(info.lastInsertRowid);

  res.status(201).json({
    ...row,
    config_json: safeParseJson(row.config_json),
  });
});

router.put("/widgets/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const { screen_id, type, name, x, y, width, height, config_json } = req.body;

  if (!screen_id || !type || !name) {
    return res.status(400).json({
      error: "screen_id, type y name son obligatorios para el widget",
    });
  }

  const db = getDb();

  const existing = db
    .prepare("SELECT id FROM widgets WHERE id = ?")
    .get(id);
  if (!existing) {
    return res.status(404).json({ error: "widget no encontrado" });
  }

  const screen = db
    .prepare("SELECT id FROM screens WHERE id = ?")
    .get(screen_id);
  if (!screen) {
    return res.status(400).json({ error: "screen_id no existe" });
  }

  const cfgText =
    config_json === undefined || config_json === null
      ? "{}"
      : JSON.stringify(config_json);

  const stmt = db.prepare(
    `UPDATE widgets
     SET screen_id = @screen_id,
         type = @type,
         name = @name,
         x = @x,
         y = @y,
         width = @width,
         height = @height,
         config_json = @config_json
     WHERE id = @id`
  );

  stmt.run({
    id,
    screen_id,
    type,
    name,
    x: x ?? 0,
    y: y ?? 0,
    width: width ?? 100,
    height: height ?? 100,
    config_json: cfgText,
  });

  const row = db
    .prepare(
      `SELECT id, screen_id, type, name, x, y, width, height, config_json
       FROM widgets
       WHERE id = ?`
    )
    .get(id);

  res.json({
    ...row,
    config_json: safeParseJson(row.config_json),
  });
});

router.delete("/widgets/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const db = getDb();
  const info = db.prepare("DELETE FROM widgets WHERE id = ?").run(id);

  if (info.changes === 0) {
    return res.status(404).json({ error: "widget no encontrado" });
  }

  res.status(204).send();
});

function safeParseJson(input: string | null): any {
  if (!input) return {};
  try {
    return JSON.parse(input);
  } catch {
    return {};
  }
}

export default router;
