# Spec_Script_Editor_EBO.md
**Producto:** DX‑Ascend BMS (Workstation)  
**Módulo:** Script Editor (EBO‑compatible)  
**Stack objetivo:** Flutter (Windows Desktop)  
**Propósito del documento:** Especificación funcional y técnica, lista para que Codex implemente el módulo “Script Editor” en el proyecto Flutter/Windows.

---

## 0. Alcance y objetivos

### 0.1 Objetivo principal
Implementar en la Workstation de DX‑Ascend un **editor de scripts** con experiencia de uso inspirada en el **Script Editor de EcoStruxure Building Operation (EBO)** y con soporte explícito para:
- Edición de **Script Programs** y **Script Functions**
- Paneles auxiliares: **Variables**, **Bindings**, **Check/Errors**, **Clipboard**, **Code Library**
- Flujo de **Check + Save** y ejecución (Run/Restart) mediante integración con el backend de Ascend Server
- **Import / Export** de texto, y **conversión** de Plain English (PE) a Script (si el backend lo provee)
- **Depuración** (debugger) con breakpoints / step / go / trace / set next statement (si el backend lo provee)
- **Protección de código** (protect/unprotect) con password (si el backend lo provee)

> Nota: Este módulo es “EBO‑compatible” a nivel UX + reglas de edición + semántica de variables/bindings. La compilación/ejecución real debe ser responsabilidad del Ascend Server (API), no del cliente.

### 0.2 No‑objetivos (por defecto)
- Implementar el **compilador** del lenguaje Script en Flutter.
- Implementar un motor de ejecución local.
- Reproducir exactamente el UI visual de EBO (se replica el comportamiento y estructura, con una UI moderna/consistente con Ascend).

---

## 1. Referencias del comportamiento EBO (fuente)
Este módulo debe reflejar las reglas y flujos descritos en el documento **EcoStruxure Building Operation – Programming** (secciones de Script Editor, Script Debugger, Code protection, etc.).  
Usar como guía explícita:  
- Script Editor: features, colors, shortcuts, collapsible code segments, clipboard, code library, check/save, import/export, PE convert, options (General / Fonts & Colors / Paths).  
- Debugger: start/stop/step/go/trace/breakpoints/next statement, límites y restricciones.
- Code protection: reglas de password, compatibilidad, limitaciones.

---

## 2. Conceptos clave (glosario operativo)

### 2.1 Script Program vs Script Function
- **Script Program**: se estructura en **líneas (lines)**, donde una “line” es una unidad de ejecución bajo un **line label** (por ejemplo `Line <label>` o `<label>:`).  
- **Script Function**: no utiliza “lines” como unidades de ejecución; se compone de **declarations y statements**; comienza con declaraciones (incluyendo `ARG`) y luego statements.

**Implicancia para el editor:** el editor debe soportar ambos tipos (Program/Function) y ajustar:
- Plantillas iniciales (snippet)
- Validaciones ligeras (p. ej., “Add line” no aplica a funciones)
- Restricciones de importación PE: **no se permite importar PE en una función**.

### 2.2 Variables y bindings (en el editor)
- “Bindings” vinculan variables del script con propiedades/valores del sistema (en EBO: objetos, puntos BACnet, etc.).  
- En Ascend: un binding vincula una variable a una **ruta** (p. ej., objectId/pointId + property + metadata adicional, como prioridad BACnet si aplica).

### 2.3 Start Value vs valor proveniente del binding
Se deben contemplar dos métodos de inicialización:
1) Inicialización por **statements** en el programa  
2) Inicialización por el campo **Start Value** en el panel Variables

Regla: si la variable está **bound** a un valor externo, el valor inicial efectivo proviene del binding (no del Start Value local), salvo que el backend defina otra política.

### 2.4 Restricciones de caracteres y longitud de línea
- Respetar compatibilidad de caracteres ASCII (≤ 127).
- Recomendar tope de longitud por línea: 132 caracteres (alerta visual, no bloqueo).

---

## 3. UX / UI: Pantalla principal del Script Editor

### 3.1 Layout (desktop)
Diseño recomendado (Dock Layout):
- **Top App Bar / Toolbar**
- **Área central**: Code Editor (principal)
- **Panel derecho**: Bindings (dockable, colapsable)
- **Panel inferior (tabs)**: Variables / Check / Clipboard / Library

Debe ser posible:
- Mostrar/ocultar paneles.
- Recordar layout (persistencia local por usuario).
- Modo “Tabbed documents” o “Multiple documents” (ver §4.1).

### 3.2 Barra de herramientas (acciones)
Agrupar por contexto:

**Edición**
- New (Program / Function) [opcional si ya existe un “explorer” de objetos]
- Open (desde árbol/lista de objetos o file open local si se soporta “offline”)
- Save
- Undo / Redo
- Find (campo rápido)
- Replace (dialog)
- Toggle line numbers
- Toggle IntelliSense
- Toggle outlining (code folding)
- Comment/Uncomment selection (atajos + botón)

**Compilación / verificación**
- Check (validación sintáctica / pre‑compilación, siempre backend o validador local superficial)
- Clear errors

**Ejecución (si el backend lo habilita)**
- Run / Restart
- Stop
- Observe runtime fields (TS/TM/TH u equivalentes de Ascend)

**Depuración (si el backend lo habilita)**
- Start debugging
- Stop debugging
- Trace On / Trace Off
- Step
- Go
- Set breakpoint
- Clear breakpoints
- Set next statement

**Gestión de soporte**
- Import (Text / Plain English)
- Export
- Convert Plain English (si no es parte del Import)
- Options (General / Fonts & Colors / Paths)
- Protect / Unprotect (si el backend lo habilita)

> Importante: deshabilitar/ocultar acciones no aplicables por tipo de documento (Program vs Function) o por capabilities del servidor.

### 3.3 Code editor (componente)
Requisitos mínimos:
- Monoespaciado + zoom
- Selección múltiple (deseable)
- Número de línea (opcional)
- Estado Insert/Overwrite
- Syntax highlighting por categorías (ver §4.2)
- IntelliSense / sugerencias (ver §4.3)
- Folding (ver §4.4)
- Marcadores en gutter:
  - Breakpoints
  - Indicador de línea actual durante debugging
  - Indicador de errores (por línea)

Recomendación técnica en Windows:
- **Opción A (preferida): Monaco Editor embebido en WebView** (mejor soporte de folding/suggestions/breakpoints)
- Opción B: editor nativo Flutter (p. ej. `flutter_code_editor`) + extensiones (mayor trabajo para igualar funcionalidades)

> Implementar con una abstracción `IScriptTextEditor` para poder cambiar motor sin reescribir el módulo.

---

## 4. Comportamientos de edición (reglas determinísticas)

### 4.1 “Tabbed documents” vs “Multiple documents”
- “Tabbed documents”: cada programa/función abierto aparece como tab.
- “Multiple documents”: ventanas/panes internos múltiples (en Ascend se puede emular como tabs + split view).

Persistir la preferencia del usuario.

### 4.2 Syntax Highlighting (colores por defecto)
Definir al menos las siguientes categorías:
- Text
- Keyword
- Function
- Value
- String
- Number
- Operator
- Comment

Permitir customización del usuario (ver §5.2).

### 4.3 IntelliSense / auto‑completion
- Cuando está habilitado, el editor debe sugerir:
  - Keywords del lenguaje Script
  - Nombres de funciones (incluyendo librería + user functions si se detectan)
  - Constantes
- Debe existir “quick info” (tooltip) en funciones: firma, parámetros, descripción (si está disponible en catálogo local o del backend).
- Debe ser posible deshabilitar IntelliSense.

Nota: si se usa Monaco, implementar provider `CompletionItemProvider`.

### 4.4 Outlining / Collapsible Code Segments (folding)
El editor debe permitir colapsar/expandir bloques para:
- `For ... Next`
- `While ... Endwhile`
- `Repeat ... Until`
- `Select Case ... Endselect`

En modo colapsado, mostrar una línea resumen con el keyword del bloque.

### 4.5 Clipboard pane (historial interno de copiar/cortar)
- Mantener un historial (lista) de fragments copiados/cortados dentro del Script Editor.
- Permitir “insert” en el punto del cursor con doble‑click del ítem.
- Mantener compatibilidad con clipboard del sistema operativo (Ctrl+C/V), pero el pane es adicional.

Configuración:
- Tamaño máximo del historial (por defecto 50).
- Opción “pin” para ítems frecuentes.

### 4.6 Code Library
La Code Library es un repositorio de “entries” organizadas en carpetas, almacenadas localmente (por usuario) y opcionalmente sincronizadas (si Ascend lo define).

Funciones mínimas:
- Crear carpeta
- Renombrar carpeta
- Eliminar carpeta
- Agregar entry desde selección actual (“Add to library”)
- Insertar entry en el editor (“Insert in editor”)
- Renombrar entry
- Eliminar entry
- Mover entry a otra carpeta

También debe existir un set “System‑Provided” (read‑only) de entradas (programas/funciones/samples) que el usuario puede insertar como ejemplo.

### 4.7 Find / Replace
- Find rápido desde toolbar (busca solo en el documento actual).
- Dialog “Find” (Ctrl+F) con:
  - Match case
  - Whole word
  - Find next / previous
- Dialog “Replace” (Ctrl+H) con:
  - Replace next / Replace all

### 4.8 Undo / Redo
- Implementar undo/redo.
- Implementar un límite de historia configurable (por defecto 24 operaciones para emular el comportamiento referencial).

### 4.9 Keyboard shortcuts (mínimos)
- Ctrl+C / Ctrl+Insert: Copy
- Ctrl+X / Shift+Delete: Cut
- Ctrl+V / Shift+Insert: Paste
- Ctrl+F: Find
- Ctrl+H: Replace
- Ctrl+Z: Undo
- Ctrl+Y: Redo
- Insert: Toggle insert/overwrite
- Backspace/Delete/Enter: edición estándar

Depuración (si aplica):
- F5: Go / Start
- F9: Breakpoint toggle
- F10: Step

---

## 5. Options (customización)

### 5.1 General
- Tabbed documents (bool)
- Multiple documents (bool) — mutual exclusive con Tabbed
- Enable IntelliSense (bool)
- Enable outlining (bool)
- Show line numbers (bool)
- Restore default settings (action)

### 5.2 Fonts & Colors
- Font family (dropdown)
- Font size
- Mapeo de colores por categoría (ver §4.2)
- Apply (aplica sin cerrar)

### 5.3 Paths
- Code library path (local folder)
- Import/export path (local folder)
- Restore default para ambos

Persistencia:
- Guardar en configuración del usuario (local) y opcionalmente en perfil del servidor.

---

## 6. Flujo “Check + Save” y errores

### 6.1 Check
- Acción “Check” ejecuta validación y pobla el panel **Check** con errores (y warnings).
- Doble click en error navega a línea/columna.

Modelo de error:
- severity: error|warning|info
- message
- line
- column
- code (si existe)
- source (backend|local)

### 6.2 Save
- “Save” debe ejecutar:
  1) Check
  2) si Check OK => persistir en backend (y/o filesystem si es local)
- Regla: si el documento contiene errores, **no debe poder ejecutarse** (bloqueo de Run/Restart).
- Para compatibilidad, puede mostrarse un toast “Save Successful” aunque existan errores; pero Ascend debería mostrar claramente el estado “Saved with errors / Not runnable” (UX mejor).

### 6.3 Auto‑actualización de Binding Tabs (comportamiento referencial)
Al guardar, si hay variables declaradas del tipo:
- Input
- Output
- Public
- Function
- WebService

…deben reflejarse automáticamente en la UI de bindings (en EBO: binding tabs en properties). En Ascend: actualizar la lista de bindings sugeridos o requeridos.

---

## 7. Ejecución (Run/Restart) y runtime

### 7.1 Modelo de ejecución
- El editor no ejecuta localmente. Llama a:
  - `POST /scripts/{id}/restart` (o equivalente)
  - `POST /scripts/{id}/stop`
  - `GET /scripts/{id}/runtime` (TS/TM/TH u otro)

### 7.2 Observabilidad
Mostrar en un panel “Runtime” (puede ser en el status bar):
- Estado: Running / Stopped / Error
- Último start
- “Runtime fields” (si el backend expone)

---

## 8. Import / Export / Convert Plain English

### 8.1 Import
Soportar import de:
- Texto (script)
- Plain English (.txt) sujeto a conversión

Reglas:
- Se puede importar PE en Script program y Script event program.
- No se permite importar PE dentro de una Script function.

UX:
- Insertar en posición del cursor (insertion point).
- Al finalizar import: solicitar Save.

### 8.2 Export
- Exportar selección del editor (o todo el documento) a `.txt`.
- Selección de path por defecto desde Options → Paths.

### 8.3 Convert Plain English
Si el backend soporta conversión:
- Import Plain English dialog:
  - Load file (cargar archivo completo)
  - Editor pane (pegar fragmento)
  - Convert all / Convert selected
- Luego se deben corregir errores y guardar.

---

## 9. Debugger (si el backend/capability lo permite)

### 9.1 Precondiciones y restricciones
- Solo un Script program puede estar en debug por vez.
- Pueden existir restricciones por plataforma/controlador (si aplica en Ascend).

### 9.2 Breakpoints
- Toggle por tecla (F9) y por click en gutter.
- Persistencia por documento (local) y opcionalmente sincronizada.

### 9.3 Running / stepping / trace
- Start debugging: inicia sesión
- Stop debugging: termina sesión
- Go (F5): corre hasta breakpoint o fin
- Step (F10): ejecuta statement actual y avanza
- Trace On:
  - resalta statement en ejecución
  - permite configurar Trace timer (ms)
  - opción “Stop in breakpoint while tracing” (si se soporta)

### 9.4 Set next statement
- Permite mover el “instruction pointer” a otra línea/statement (solo en modo debug).

### 9.5 Edición de valores durante debugging
- Permitir editar valores en:
  - Local variables
  - Binding variables
- Validar tipo y rango (si el backend provee tipos).

---

## 10. Code Protection (Protect / Unprotect)

### 10.1 Requisitos
- Proteger un Script Program / Function con password.
- El código protegido **no debe ser visible ni editable** hasta “Unprotect”.
- El objeto protegido puede continuar ejecutándose, copiándose, exportándose o borrándose (si el backend mantiene compatibilidad referencial).

### 10.2 Reglas de password
- Longitud: 4 a 25 caracteres
- No existe recuperación de password (“no password recovery”): si se pierde, no se puede desbloquear.

### 10.3 Compatibilidad de versiones
Si el backend tiene comportamiento de “versión mínima” para protección, reflejarlo en UI:
- Si serverVersion < minProtectedVersion => deshabilitar “Protect”, o advertir.

---

## 11. Modelos de datos (API/UI)

### 11.1 ScriptDocument
- id: string
- name: string
- type: enum { program, function, eventProgram }
- content: string
- isDirty: bool
- isProtected: bool
- lastSavedAt: DateTime?
- capabilities:
  - canRun
  - canDebug
  - canProtect
  - canImportPE
  - canConvertPE
- editorSettings (override local o global):
  - showLineNumbers
  - enableIntelliSense
  - enableOutlining
  - fontFamily
  - fontSize
  - colorTheme (map)

### 11.2 ScriptVariable
- name: string
- qualifier: enum { local, input, output, public, function, webService, arg }
- dataType: string (o enum tipada si Ascend la define)
- startValue: string?
- currentValue: string? (si runtime/debug)
- isBound: bool
- bindingRefId: string?

### 11.3 ScriptBinding
- id: string
- variableName: string
- target:
  - objectId / pointId
  - property
  - (opcional) priority
- direction: enum { input, output, bidirectional }
- flags:
  - isValidOffline (si aplica)
  - isOverridden (si aplica)

### 11.4 ScriptCheckResult
- ok: bool
- items: list<ScriptDiagnostic>

### 11.5 ScriptDiagnostic
- severity
- message
- line
- column
- code

### 11.6 CodeLibrary
- rootPath: string
- folders: list<CodeLibraryFolder>
- systemFolders: list<CodeLibraryFolder> (read-only)

---

## 12. Arquitectura Flutter recomendada

### 12.1 Paquetes (sugeridos)
- `flutter_riverpod` (state management) o `provider`
- `freezed` + `json_serializable` (modelos)
- `dio` (HTTP API)
- `shared_preferences` o `hive` (persistencia settings/layout)
- WebView (si Monaco):
  - `webview_windows` o `flutter_inappwebview` (según compatibilidad del proyecto)

### 12.2 Estructura de carpetas (propuesta)
```
lib/
  features/script_editor/
    presentation/
      script_editor_screen.dart
      widgets/
        editor_toolbar.dart
        dock_layout.dart
        variables_panel.dart
        bindings_panel.dart
        check_panel.dart
        clipboard_panel.dart
        code_library_panel.dart
        options_dialog.dart
    domain/
      models/
        script_document.dart
        script_variable.dart
        script_binding.dart
        script_diagnostics.dart
        editor_settings.dart
      services/
        script_language_service.dart     // tokens, keywords, completions
    data/
      repositories/
        script_repository.dart           // API
      storage/
        editor_settings_store.dart
        code_library_store.dart
```

### 12.3 Integración Monaco (si aplica)
- `assets/monaco/index.html` + JS bridge.
- Canales:
  - `editorReady`
  - `contentChanged`
  - `cursorChanged`
  - `requestCompletions`
  - `toggleBreakpoint`
  - `applyDiagnostics`
  - `setDebugExecutionLine`

---

## 13. Criterios de aceptación (Definition of Done)

### 13.1 Edición básica
- Abrir Script Program y Script Function.
- Editar contenido, Undo/Redo, Find/Replace.
- Show line numbers on/off.
- Insert/Overwrite visible.

### 13.2 Highlighting y folding
- Colores por categoría (default).
- Folding operativo en los 4 bloques exigidos.

### 13.3 Panels
- Variables panel lista variables (parse básico).
- Check panel muestra errores con navegación.
- Clipboard panel registra copias/cortes y permite insert con doble‑click.
- Code library panel con carpetas/entries, insert en editor.

### 13.4 Check/Save y ejecución
- Check con errores y navegación.
- Save llama a API y actualiza estado “dirty”.
- Run/Restart bloqueado si Check no OK.

### 13.5 Import/Export
- Import Text inserta en cursor.
- Import PE bloqueado en Function.
- Export selección a txt.
- Paths configurables.

### 13.6 Debug (si disponible)
- Breakpoints toggle.
- Step / Go / Trace On (UI + llamadas a API).
- Set next statement (UI + llamada a API).

### 13.7 Protección (si disponible)
- Protect/Unprotect con password.
- UI bloquea edición si protected.

---

## 14. Notas para Codex (ejecución determinística)
- Implementar primero el UI/UX y el editor (Monaco recomendado).
- Implementar el parsing mínimo de variables y bloques (regex + heurísticas) para poblar paneles.
- Implementar interfaces de repositorio con mocks:
  - `ScriptRepositoryMock` para desarrollo offline.
- Dejar “capabilities” consultables desde backend (`GET /server/capabilities`) para habilitar/ocultar acciones.

---
