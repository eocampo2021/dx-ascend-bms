import express from 'express';
import cors from 'cors'; // Importar CORS
import path from 'path';
import runtimeRoutes from './api/runtime.routes';
import systemObjectsRoutes from './api/system-objects.routes'; // Importar nueva ruta
import screensRoutes from './api/screens.routes';

const app = express();

// Middleware
app.use(cors()); // Habilitar CORS para todas las rutas
app.use(express.json());
app.use(express.static('public'));

// Routes
app.use('/api/runtime', runtimeRoutes);
app.use('/api/system-objects', systemObjectsRoutes); // Registrar ruta del arbol
app.use('/api', screensRoutes);

// Renderizador web simple: /runtime/1, /runtime/2, etc.
app.get(['/runtime/:id', '/runtime'], (_req, res) => {
  res.sendFile(path.join(__dirname, '../public/runtime.html'));
});

export default app;
