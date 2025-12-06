import { Router, Request, Response } from "express";
import { getDb } from "../config/db";

const router = Router();

/* =========================
 *  INTERFACES MODBUS
 * ========================= */

router.get("/modbus/interfaces", (req: Request, res: Response) => {
  const db = getDb();
  const rows = db
    .prepare(
      "SELECT id, name, ip_address, port, polling_ms, enabled FROM modbus_interfaces ORDER BY id"
    )
    .all();
  res.json(rows);
});

router.post("/modbus/interfaces", (req: Request, res: Response) => {
  const { name, ip_address, port, polling_ms, enabled } = req.body;

  if (!name || !ip_address) {
    return res.status(400).json({ error: "name e ip_address son obligatorios" });
  }

  const db = getDb();
  const stmt = db.prepare(
    `INSERT INTO modbus_interfaces (name, ip_address, port, polling_ms, enabled)
     VALUES (@name, @ip_address, @port, @polling_ms, @enabled)`
  );

  const info = stmt.run({
    name,
    ip_address,
    port: port ?? 502,
    polling_ms: polling_ms ?? 1000,
    enabled: enabled === undefined ? 1 : enabled ? 1 : 0,
  });

  const row = db
    .prepare(
      "SELECT id, name, ip_address, port, polling_ms, enabled FROM modbus_interfaces WHERE id = ?"
    )
    .get(info.lastInsertRowid);

  res.status(201).json(row);
});

router.put("/modbus/interfaces/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const { name, ip_address, port, polling_ms, enabled } = req.body;
  const db = getDb();

  const existing = db
    .prepare("SELECT id FROM modbus_interfaces WHERE id = ?")
    .get(id);
  if (!existing) {
    return res.status(404).json({ error: "interface no encontrada" });
  }

  const stmt = db.prepare(
    `UPDATE modbus_interfaces
     SET name = @name,
         ip_address = @ip_address,
         port = @port,
         polling_ms = @polling_ms,
         enabled = @enabled
     WHERE id = @id`
  );

  stmt.run({
    id,
    name,
    ip_address,
    port: port ?? 502,
    polling_ms: polling_ms ?? 1000,
    enabled: enabled === undefined ? 1 : enabled ? 1 : 0,
  });

  const row = db
    .prepare(
      "SELECT id, name, ip_address, port, polling_ms, enabled FROM modbus_interfaces WHERE id = ?"
    )
    .get(id);

  res.json(row);
});

router.delete("/modbus/interfaces/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const db = getDb();
  const stmt = db.prepare("DELETE FROM modbus_interfaces WHERE id = ?");
  const info = stmt.run(id);

  if (info.changes === 0) {
    return res.status(404).json({ error: "interface no encontrada" });
  }

  res.status(204).send();
});

/* =========================
 *  DISPOSITIVOS MODBUS
 * ========================= */

router.get("/modbus/devices", (req: Request, res: Response) => {
  const db = getDb();
  const interfaceIdRaw = req.query.interface_id as string | undefined;

  let rows;
  if (interfaceIdRaw) {
    const interfaceId = Number(interfaceIdRaw);
    if (!Number.isFinite(interfaceId)) {
      return res.status(400).json({ error: "interface_id inválido" });
    }
    rows = db
      .prepare(
        `SELECT id, interface_id, name, slave_id, timeout_ms, enabled
         FROM modbus_devices
         WHERE interface_id = ?
         ORDER BY id`
      )
      .all(interfaceId);
  } else {
    rows = db
      .prepare(
        `SELECT id, interface_id, name, slave_id, timeout_ms, enabled
         FROM modbus_devices
         ORDER BY id`
      )
      .all();
  }

  res.json(rows);
});

router.post("/modbus/devices", (req: Request, res: Response) => {
  const { interface_id, name, slave_id, timeout_ms, enabled } = req.body;

  if (!interface_id || !name || slave_id === undefined) {
    return res
      .status(400)
      .json({ error: "interface_id, name y slave_id son obligatorios" });
  }

  const db = getDb();

  const iface = db
    .prepare("SELECT id FROM modbus_interfaces WHERE id = ?")
    .get(interface_id);
  if (!iface) {
    return res.status(400).json({ error: "interface_id no existe" });
  }

  const stmt = db.prepare(
    `INSERT INTO modbus_devices (interface_id, name, slave_id, timeout_ms, enabled)
     VALUES (@interface_id, @name, @slave_id, @timeout_ms, @enabled)`
  );

  const info = stmt.run({
    interface_id,
    name,
    slave_id,
    timeout_ms: timeout_ms ?? 1000,
    enabled: enabled === undefined ? 1 : enabled ? 1 : 0,
  });

  const row = db
    .prepare(
      `SELECT id, interface_id, name, slave_id, timeout_ms, enabled
       FROM modbus_devices WHERE id = ?`
    )
    .get(info.lastInsertRowid);

  res.status(201).json(row);
});

router.put("/modbus/devices/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const { interface_id, name, slave_id, timeout_ms, enabled } = req.body;
  const db = getDb();

  const existing = db
    .prepare("SELECT id FROM modbus_devices WHERE id = ?")
    .get(id);
  if (!existing) {
    return res.status(404).json({ error: "device no encontrado" });
  }

  if (!interface_id || !name || slave_id === undefined) {
    return res
      .status(400)
      .json({ error: "interface_id, name y slave_id son obligatorios" });
  }

  const iface = db
    .prepare("SELECT id FROM modbus_interfaces WHERE id = ?")
    .get(interface_id);
  if (!iface) {
    return res.status(400).json({ error: "interface_id no existe" });
  }

  const stmt = db.prepare(
    `UPDATE modbus_devices
     SET interface_id = @interface_id,
         name = @name,
         slave_id = @slave_id,
         timeout_ms = @timeout_ms,
         enabled = @enabled
     WHERE id = @id`
  );

  stmt.run({
    id,
    interface_id,
    name,
    slave_id,
    timeout_ms: timeout_ms ?? 1000,
    enabled: enabled === undefined ? 1 : enabled ? 1 : 0,
  });

  const row = db
    .prepare(
      `SELECT id, interface_id, name, slave_id, timeout_ms, enabled
       FROM modbus_devices WHERE id = ?`
    )
    .get(id);

  res.json(row);
});

router.delete("/modbus/devices/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const db = getDb();
  const info = db.prepare("DELETE FROM modbus_devices WHERE id = ?").run(id);

  if (info.changes === 0) {
    return res.status(404).json({ error: "device no encontrado" });
  }

  res.status(204).send();
});

/* =========================
 *  DATAPOINTS MODBUS
 * ========================= */

router.get("/modbus/datapoints", (req: Request, res: Response) => {
  const db = getDb();
  const deviceIdRaw = req.query.device_id as string | undefined;

  let rows;
  if (deviceIdRaw) {
    const deviceId = Number(deviceIdRaw);
    if (!Number.isFinite(deviceId)) {
      return res.status(400).json({ error: "device_id inválido" });
    }
    rows = db
      .prepare(
        `SELECT id, device_id, name, function, address, quantity, datatype,
                scale, offset, unit, rw, polling_ms, enabled
         FROM datapoints
         WHERE device_id = ?
         ORDER BY id`
      )
      .all(deviceId);
  } else {
    rows = db
      .prepare(
        `SELECT id, device_id, name, function, address, quantity, datatype,
                scale, offset, unit, rw, polling_ms, enabled
         FROM datapoints
         ORDER BY id`
      )
      .all();
  }

  res.json(rows);
});

router.post("/modbus/datapoints", (req: Request, res: Response) => {
  const {
    device_id,
    name,
    function: fn,
    address,
    quantity,
    datatype,
    scale,
    offset,
    unit,
    rw,
    polling_ms,
    enabled,
  } = req.body;

  if (!device_id || !name || !fn || address === undefined || !datatype) {
    return res.status(400).json({
      error:
        "device_id, name, function, address y datatype son obligatorios",
    });
  }

  const db = getDb();

  const dev = db
    .prepare("SELECT id FROM modbus_devices WHERE id = ?")
    .get(device_id);
  if (!dev) {
    return res.status(400).json({ error: "device_id no existe" });
  }

  const stmt = db.prepare(
    `INSERT INTO datapoints
     (device_id, name, function, address, quantity, datatype,
      scale, offset, unit, rw, polling_ms, enabled)
     VALUES
     (@device_id, @name, @function, @address, @quantity, @datatype,
      @scale, @offset, @unit, @rw, @polling_ms, @enabled)`
  );

  const info = stmt.run({
    device_id,
    name,
    function: fn,
    address,
    quantity: quantity ?? 1,
    datatype,
    scale: scale ?? 1.0,
    offset: offset ?? 0.0,
    unit: unit ?? null,
    rw: rw ?? "R",
    polling_ms: polling_ms ?? null,
    enabled: enabled === undefined ? 1 : enabled ? 1 : 0,
  });

  const row = db
    .prepare(
      `SELECT id, device_id, name, function, address, quantity, datatype,
              scale, offset, unit, rw, polling_ms, enabled
       FROM datapoints
       WHERE id = ?`
    )
    .get(info.lastInsertRowid);

  res.status(201).json(row);
});

router.put("/modbus/datapoints/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const {
    device_id,
    name,
    function: fn,
    address,
    quantity,
    datatype,
    scale,
    offset,
    unit,
    rw,
    polling_ms,
    enabled,
  } = req.body;

  const db = getDb();

  const existing = db
    .prepare("SELECT id FROM datapoints WHERE id = ?")
    .get(id);
  if (!existing) {
    return res.status(404).json({ error: "datapoint no encontrado" });
  }

  if (!device_id || !name || !fn || address === undefined || !datatype) {
    return res.status(400).json({
      error:
        "device_id, name, function, address y datatype son obligatorios",
    });
  }

  const dev = db
    .prepare("SELECT id FROM modbus_devices WHERE id = ?")
    .get(device_id);
  if (!dev) {
    return res.status(400).json({ error: "device_id no existe" });
  }

  const stmt = db.prepare(
    `UPDATE datapoints
     SET device_id = @device_id,
         name = @name,
         function = @function,
         address = @address,
         quantity = @quantity,
         datatype = @datatype,
         scale = @scale,
         offset = @offset,
         unit = @unit,
         rw = @rw,
         polling_ms = @polling_ms,
         enabled = @enabled
     WHERE id = @id`
  );

  stmt.run({
    id,
    device_id,
    name,
    function: fn,
    address,
    quantity: quantity ?? 1,
    datatype,
    scale: scale ?? 1.0,
    offset: offset ?? 0.0,
    unit: unit ?? null,
    rw: rw ?? "R",
    polling_ms: polling_ms ?? null,
    enabled: enabled === undefined ? 1 : enabled ? 1 : 0,
  });

  const row = db
    .prepare(
      `SELECT id, device_id, name, function, address, quantity, datatype,
              scale, offset, unit, rw, polling_ms, enabled
       FROM datapoints
       WHERE id = ?`
    )
    .get(id);

  res.json(row);
});

router.delete("/modbus/datapoints/:id", (req: Request, res: Response) => {
  const id = Number(req.params.id);
  if (!Number.isFinite(id)) {
    return res.status(400).json({ error: "id inválido" });
  }

  const db = getDb();
  const info = db.prepare("DELETE FROM datapoints WHERE id = ?").run(id);

  if (info.changes === 0) {
    return res.status(404).json({ error: "datapoint no encontrado" });
  }

  res.status(204).send();
});

export default router;
