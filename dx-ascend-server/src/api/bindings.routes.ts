import { Router, Request, Response } from "express";
import { getDb } from "../config/db";

const router = Router();

router.get("/bindings", (req: Request, res: Response) => {
  const db = getDb();
  const { screen_id, widget_id, datapoint_id } = req.query;

  let where = "";
  const params: any[] = [];

  if (screen_id) {
    where += (where ? " AND " : " WHERE ") + "s.id = ?";
    params.push(Number(screen_id));
  }
  if (widget_id) {
    where += (where ? " AND " : " WHERE ") + "w.id = ?";
    params.push(Number(widget_id));
  }
  if (datapoint_id) {
    where += (where ? " AND " : " WHERE ") + "d.id = ?";
    params.push(Number(datapoint_id));
  }

  const sql = `
    SELECT
      b.id,
      b.mode,
      b.expression,
      w.id   AS widget_id,
      w.name AS widget_name,
      s.id   AS screen_id,
      s.name AS screen_name,
      d.id   AS datapoint_id,
      d.name AS datapoint_name,
      d.function AS datapoint_function,
      d.address  AS datapoint_address,
      d.unit     AS datapoint_unit
    FROM bindings b
    JOIN widgets    w ON w.id = b.widget_id
    JOIN screens    s ON s.id = w.screen_id
    JOIN datapoints d ON d.id = b.datapoint_id
    ${where}
    ORDER BY s.id, w.id, b.id
  `;

  const rows = db.prepare(sql).all(...params);
  res.json(rows);
});

router.post("/bindings", (req: Request, res: Response) => {
  const { widget_id, datapoint_id, mode, expression } = req.body;

  if (!widget_id || !datapoint_id) {
    return res
      .status(400)
      .json({ error: "widget_id y datapoint_id son obligatorios" });
  }

  const db = getDb();

  const widget = db
    .prepare("SELECT id FROM widgets WHERE id = ?")
    .get(widget_id);
  if (!widget) {
    return res.status(400).json({ error: "widget_id no existe" });
  }

  const datapoint = db
    .prepare("SELECT id FROM datapoints WHERE id = ?")
    .get(datapoint_id);
  if (!datapoint) {
    return res.status(400).json({ error: "datapoint_id no existe" });
  }

  const stmt = db.prepare(
    `INSERT INTO bindings (widget_id, datapoint_id, mode, expression)
     VALUES (@widget_id, @datapoint_id, @mode, @expression)`
  );

  const info = stmt.run({
    widget_id,
    datapoint_id,
    mode: mode ?? "read",
    expression: expression ?? null,
  });

  const row = db
    .prepare(
      `
      SELECT
        b.id,
        b.mode,
        b.expression,
        w.id   AS widget_id,
        w.name AS widget_name,
        s.id   AS screen_id,
        s.name AS screen_name,
        d.id   AS datapoint_id,
        d.name AS datapoint_name,
        d.function AS datapoint_function,
        d.address  AS datapoint_address,
        d.unit     AS datapoint_unit
      FROM bindings b
      JOIN widgets    w ON w.id = b.widget_id
      JOIN screens    s ON s.id = w.screen_id
      JOIN datapoints d ON d.id = b.datapoint_id
      WHERE b.id = ?
    `
    )
    .get(info.lastInsertRowid);

  res.status(201).json(row);
});

router.delete("/bindings/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const db = getDb();
  const info = db.prepare("DELETE FROM bindings WHERE id = ?").run(id);

  if (info.changes === 0) {
    return res.status(404).json({ error: "binding no encontrado" });
  }

  res.status(204).send();
});

export default router;
