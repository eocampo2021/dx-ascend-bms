import { Router, Request, Response } from 'express';
import { getDb } from '../config/db';

const router = Router();

const serializeProperties = (properties: unknown) => {
    if (properties === undefined) {
        return JSON.stringify({});
    }
    if (properties && typeof properties === 'object') {
        return JSON.stringify(properties);
    }
    return properties;
};

// Obtener todo el árbol (Flat list que el frontend convertirá en árbol)
router.get('/', (req: Request, res: Response) => {
    const db = getDb();
    try {
        const stmt = db.prepare('SELECT * FROM system_objects ORDER BY type DESC, name ASC');
        const objects = stmt.all();

        const screens = db
            .prepare('SELECT id, name, route, description FROM screens WHERE enabled = 1 ORDER BY id')
            .all();

        const graphicsFolder = objects.find(
            (obj: any) => (obj.type || '').toLowerCase() === 'graphics' || (obj.name || '').toLowerCase().includes('graphic')
        );
        const parentId = graphicsFolder?.id ?? objects.find((o: any) => o.parent_id === null)?.id ?? null;

        const existingScreenIds = new Set<number>();
        for (const obj of objects) {
            try {
                const parsed = JSON.parse(obj.properties ?? '{}');
                const sid = parsed.screenId || parsed.screen_id;
                if (typeof sid === 'number') existingScreenIds.add(sid);
            } catch {
                // ignore
            }
        }

        const virtualScreens = screens
            .filter((scr: any) => !existingScreenIds.has(scr.id))
            .map((scr: any) => ({
                id: 100000 + scr.id,
                parent_id: parentId,
                name: scr.name,
                type: 'Graphic',
                description: scr.description ?? '',
                properties: JSON.stringify({ screenId: scr.id, route: scr.route }),
            }));

        res.json([...objects, ...virtualScreens]);
    } catch (error) {
        res.status(500).json({ error: 'Error fetching system tree' });
    }
});

// Crear un nuevo objeto (Carpeta, Script, Pantalla, etc)
router.post('/', (req: Request, res: Response) => {
    const db = getDb();
    const { parent_id, name, type, description, properties } = req.body;
    try {
        const stmt = db.prepare(`
            INSERT INTO system_objects (parent_id, name, type, description, properties)
            VALUES (?, ?, ?, ?, ?)
        `);
        const serializedProperties = serializeProperties(properties);
        const info = stmt.run(parent_id, name, type, description || '', serializedProperties);
        res.json({ id: info.lastInsertRowid, ...req.body });
    } catch (error) {
        res.status(500).json({ error: 'Error creating object' });
    }
});

// Actualizar un objeto (Ej: Guardar código de script o diseño de pantalla)
router.put('/:id', (req: Request, res: Response) => {
    const db = getDb();
    const { name, properties } = req.body;
    const { id } = req.params;
    try {
        const stmt = db.prepare(`
            UPDATE system_objects
            SET name = COALESCE(?, name),
                properties = COALESCE(?, properties)
            WHERE id = ?
        `);
        const serializedProperties = serializeProperties(properties);
        stmt.run(name, serializedProperties, id);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Error updating object' });
    }
});

// Borrar objeto
router.delete('/:id', (req: Request, res: Response) => {
    const db = getDb();
    try {
        const stmt = db.prepare('DELETE FROM system_objects WHERE id = ?');
        stmt.run(req.params.id);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Error deleting object' });
    }
});

export default router;