import { Router, Request, Response } from "express";
import { getDb } from "../config/db";

const router = Router();

// ---------- Helpers de simulación ----------

function simulateDatapointValue(dp: any): number | boolean {
  const now = Date.now() / 1000;
  const id = typeof dp.id === "number" ? dp.id : 0;
  const fn = (dp.function ?? "").toString().toLowerCase();

  // Simulación simple para coils / digitales
  if (fn === "coil" || fn === "discrete_input") {
    const period = 10; // segundos
    const phase = (now / period + id) % 2;
    return phase < 1;
  }

  // Analógicos
  const unit = (dp.unit ?? "").toString();
  let base = 10;

  if (unit.includes("°C") || unit.includes(" C")) {
    base = 20;
  } else if (unit.includes("%")) {
    base = 50;
  }

  const val = base + 5 * Math.sin(now / 10 + id);
  const scale = typeof dp.scale === "number" ? dp.scale : 1;
  const offset = typeof dp.offset === "number" ? dp.offset : 0;
  return val * scale + offset;
}

const SCREEN_SQL = `
  SELECT
    s.id   AS screen_id,
    s.name AS screen_name,
    s.route AS screen_route,
    s.description AS screen_description,

    w.id   AS widget_id,
    w.name AS widget_name,
    w.type AS widget_type,
    w.x, w.y, w.width, w.height,
    w.config_json AS widget_config_json,

    b.id   AS binding_id,
    b.mode AS binding_mode,

    d.id        AS datapoint_id,
    d.name      AS datapoint_name,
    d.unit      AS datapoint_unit,
    d.scale     AS datapoint_scale,
    d.offset    AS datapoint_offset,
    d.datatype  AS datapoint_datatype,
    d.function  AS datapoint_function,
    d.address   AS datapoint_address
  FROM screens s
  JOIN widgets w ON w.screen_id = s.id
  LEFT JOIN bindings b ON b.widget_id = w.id
  LEFT JOIN datapoints d ON d.id = b.datapoint_id
  WHERE s.id = ?
  ORDER BY w.id, b.id
`;

// Construye el “runtime” de una pantalla por ID
function buildRuntimeForScreenId(screenId: number) {
  const db = getDb();

  const screen = db
    .prepare(
      "SELECT id, name, route, description FROM screens WHERE id = ? AND enabled = 1"
    )
    .get(screenId);

  if (!screen) {
    return null;
  }

  const rows = db.prepare(SCREEN_SQL).all(screenId) as any[];

  const widgetsMap = new Map<number, any>();

  for (const row of rows) {
    let w = widgetsMap.get(row.widget_id);
    if (!w) {
      let cfg: any = {};
      if (row.widget_config_json) {
        try {
          cfg = JSON.parse(row.widget_config_json);
        } catch {
          cfg = {};
        }
      }

      w = {
        id: row.widget_id,
        name: row.widget_name,
        type: row.widget_type,
        x: row.x,
        y: row.y,
        width: row.width,
        height: row.height,
        config: cfg,
        bindings: [] as any[],
      };
      widgetsMap.set(row.widget_id, w);
    }

    if (row.binding_id != null && row.datapoint_id != null) {
      const dp = {
        id: row.datapoint_id,
        name: row.datapoint_name,
        unit: row.datapoint_unit,
        scale: row.datapoint_scale,
        offset: row.datapoint_offset,
        datatype: row.datapoint_datatype,
        function: row.datapoint_function,
        address: row.datapoint_address,
      };

      const value = simulateDatapointValue({
        id: dp.id,
        unit: dp.unit,
        scale: dp.scale,
        offset: dp.offset,
        datatype: dp.datatype,
        function: dp.function,
      });

      w.bindings.push({
        id: row.binding_id,
        mode: row.binding_mode,
        datapoint: dp,
        value,
      });
    }
  }

  const runtime = {
    screen: {
      id: screen.id,
      name: screen.name,
      route: screen.route,
      description: screen.description,
    },
    widgets: Array.from(widgetsMap.values()),
    generatedAt: new Date().toISOString(),
  };

  return runtime;
}

// ---------- Endpoints ----------

// Listado simple de pantallas disponibles para runtime
router.get("/screens", (req: Request, res: Response) => {
  const db = getDb();
  const rows = db
    .prepare(
      "SELECT id, name, route, description FROM screens WHERE enabled = 1 ORDER BY id"
    )
    .all();
  res.json(rows);
});

// Runtime por ID de pantalla
router.get("/screen/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "screen id inválido" });
  }

  const runtime = buildRuntimeForScreenId(id);
  if (!runtime) {
    return res.status(404).json({ error: "pantalla no encontrada o deshabilitada" });
  }

  res.json(runtime);
});

// Runtime por route (ej: ?route=/sala-principal o ?route=sala-principal)
router.get("/screen-by-route", (req: Request, res: Response) => {
  const routeRaw = (req.query.route as string | undefined)?.trim();
  if (!routeRaw) {
    return res.status(400).json({ error: "falta parámetro route" });
  }

  const db = getDb();
  const screen = findScreenByRouteOrName(db, routeRaw);

  if (!screen) {
    return res.status(404).json({ error: "pantalla no encontrada para ese route" });
  }

  const runtime = buildRuntimeForScreenId(screen.id as number);
  if (!runtime) {
    return res.status(404).json({ error: "no se pudo construir runtime" });
  }

  res.json(runtime);
});

function findScreenByRouteOrName(db: any, routeRaw: string) {
  const normalized = (routeRaw ?? "").trim();
  if (!normalized) return null;

  const candidates = new Set<string>();
  candidates.add(normalized);

  const withoutSlashes = normalized.replace(/^\/+/, "");
  candidates.add(withoutSlashes);

  if (!normalized.startsWith("/")) {
    candidates.add("/" + normalized);
  }

  if (!normalized.toLowerCase().startsWith("/web/")) {
    candidates.add("/web/" + withoutSlashes);
  }

  for (const cand of candidates) {
    const screen = db
      .prepare(
        "SELECT id, name, route, description FROM screens WHERE route = ? AND enabled = 1"
      )
      .get(cand);
    if (screen) return screen;
  }

  // como último recurso, buscar por nombre exacto
  const byName = db
    .prepare(
      "SELECT id, name, route, description FROM screens WHERE lower(name) = lower(?) AND enabled = 1"
    )
    .get(normalized);
  return byName ?? null;
}

export default router;
