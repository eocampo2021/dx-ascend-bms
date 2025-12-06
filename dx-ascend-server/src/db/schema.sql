-- Tabla jerárquica para el árbol del sistema (Estilo EBO)
CREATE TABLE IF NOT EXISTS system_objects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id INTEGER,            -- NULL si es la raíz (Root)
    name TEXT NOT NULL,
    type TEXT NOT NULL,           -- 'folder', 'server', 'device', 'program', 'screen', 'point_analog', 'point_digital'
    description TEXT,
    properties TEXT,              -- JSON stringified con configuración (IP, código script, json gráfico)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES system_objects(id) ON DELETE CASCADE
);

-- Insertar nodo raíz por defecto si no existe
INSERT OR IGNORE INTO system_objects (id, parent_id, name, type, description, properties)
VALUES (1, NULL, 'Ascend Server', 'server', 'Root Server', '{}');

-- Insertar carpetas de ejemplo
INSERT OR IGNORE INTO system_objects (id, parent_id, name, type, description, properties)
VALUES (2, 1, 'IO Bus', 'folder', 'Field Devices', '{}');

INSERT OR IGNORE INTO system_objects (id, parent_id, name, type, description, properties)
VALUES (3, 1, 'Graphics', 'folder', 'User Interface', '{}');

INSERT OR IGNORE INTO system_objects (id, parent_id, name, type, description, properties)
VALUES (4, 1, 'Programs', 'folder', 'Script Programs', '{}');