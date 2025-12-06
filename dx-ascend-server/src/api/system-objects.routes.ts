import { Router, Request, Response } from 'express';
import db from '../config/db';

const router = Router();

// Obtener todo el árbol (Flat list que el frontend convertirá en árbol)
router.get('/', (req: Request, res: Response) => {
    try {
        const stmt = db.prepare('SELECT * FROM system_objects ORDER BY type DESC, name ASC');
        const objects = stmt.all();
        res.json(objects);
    } catch (error) {
        res.status(500).json({ error: 'Error fetching system tree' });
    }
});

// Crear un nuevo objeto (Carpeta, Script, Pantalla, etc)
router.post('/', (req: Request, res: Response) => {
    const { parent_id, name, type, description, properties } = req.body;
    try {
        const stmt = db.prepare(`
            INSERT INTO system_objects (parent_id, name, type, description, properties)
            VALUES (?, ?, ?, ?, ?)
        `);
        const info = stmt.run(parent_id, name, type, description || '', JSON.stringify(properties || {}));
        res.json({ id: info.lastInsertRowid, ...req.body });
    } catch (error) {
        res.status(500).json({ error: 'Error creating object' });
    }
});

// Actualizar un objeto (Ej: Guardar código de script o diseño de pantalla)
router.put('/:id', (req: Request, res: Response) => {
    const { name, properties } = req.body;
    const { id } = req.params;
    try {
        const stmt = db.prepare(`
            UPDATE system_objects 
            SET name = COALESCE(?, name), 
                properties = COALESCE(?, properties)
            WHERE id = ?
        `);
        stmt.run(name, JSON.stringify(properties), id);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Error updating object' });
    }
});

// Borrar objeto
router.delete('/:id', (req: Request, res: Response) => {
    try {
        const stmt = db.prepare('DELETE FROM system_objects WHERE id = ?');
        stmt.run(req.params.id);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Error deleting object' });
    }
});

export default router;