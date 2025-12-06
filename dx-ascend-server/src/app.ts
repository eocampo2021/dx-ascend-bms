import express from 'express';
import cors from 'cors'; // Importar CORS
import runtimeRoutes from './api/runtime.routes';
import systemObjectsRoutes from './api/system-objects.routes'; // Importar nueva ruta

const app = express();

// Middleware
app.use(cors()); // Habilitar CORS para todas las rutas
app.use(express.json());
app.use(express.static('public'));

// Routes
app.use('/api/runtime', runtimeRoutes);
app.use('/api/system-objects', systemObjectsRoutes); // Registrar ruta del arbol

export default app;