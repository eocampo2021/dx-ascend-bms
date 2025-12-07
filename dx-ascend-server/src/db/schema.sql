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

-- Tabla de pantallas publicadas
CREATE TABLE IF NOT EXISTS screens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    route TEXT NOT NULL UNIQUE,
    description TEXT,
    enabled INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Widgets que pertenecen a una pantalla
CREATE TABLE IF NOT EXISTS widgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    screen_id INTEGER NOT NULL,
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    x INTEGER DEFAULT 0,
    y INTEGER DEFAULT 0,
    width INTEGER DEFAULT 100,
    height INTEGER DEFAULT 100,
    config_json TEXT DEFAULT '{}',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (screen_id) REFERENCES screens(id) ON DELETE CASCADE
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

-- Pantalla de ejemplo publicada y enlazada al árbol (propiedades guardan el screenId)
INSERT OR IGNORE INTO screens (id, name, route, description, enabled)
VALUES (1, 'Sample AHU', '/samples/ahu-1', 'Demo graphic page', 1);

INSERT OR IGNORE INTO system_objects (id, parent_id, name, type, description, properties)
VALUES (
    5,
    3,
    'Sample AHU Graphic',
    'Graphic',
    'Linked to published screen',
    '{"screenId": 1, "route": "/samples/ahu-1"}'
);

-- Widgets de muestra para la pantalla de ejemplo
INSERT OR IGNORE INTO widgets (id, screen_id, type, name, x, y, width, height, config_json)
VALUES
    (1, 1, 'Panel', 'Header Panel', 30, 30, 200, 60, '{"title":"AHU-1"}'),
    (2, 1, 'Value', 'Supply Temp', 80, 120, 140, 80, '{"label":"Supply Air","value":"23.5°C"}'),
    (3, 1, 'Status', 'Fan Status', 260, 120, 120, 80, '{"label":"Fan","state":"ON"}');
