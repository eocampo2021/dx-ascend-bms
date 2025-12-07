# Pruebas manuales de runtime

Estas comprobaciones validan que los endpoints de runtime respondan correctamente cuando el servidor está en ejecución.

1. Iniciar el servidor (por ejemplo, en otra terminal):
   ```bash
   npm run dev
   ```
2. Verificar el listado de pantallas disponibles:
   ```bash
   curl -i http://localhost:3000/api/runtime/screens
   ```
   Esperado: respuesta HTTP 200 con un arreglo JSON de pantallas habilitadas.
3. Verificar el runtime de una pantalla específica (reemplazar `1` por un ID válido existente en la base de datos):
   ```bash
   curl -i http://localhost:3000/api/runtime/screen/1
   ```
   Esperado: respuesta HTTP 200 con el objeto `runtime` de la pantalla; 404 si el ID no existe o está deshabilitado.
