import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'models/graphic_widget.dart';
import 'models/screen.dart';
import 'models/system_object.dart';

// Configuración de conexión al Backend existente
const String apiBaseUrl = 'http://localhost:4000/api';

void main() {
  runApp(const EboWorkstationApp());
}

// ---------------------------------------------------------------------------
// TEMA Y ESTILO (EBO AESTHETICS)
// ---------------------------------------------------------------------------
class EboWorkstationApp extends StatelessWidget {
  const EboWorkstationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DX Ascend Workstation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3:
            false, // Desactivar M3 para tener un look más "Desktop/Windows clásico"
        primaryColor: const Color(0xFF3DCD58), // Verde estilo Schneider/EBO
        scaffoldBackgroundColor: const Color(0xFFF0F0F0),
        dividerColor: const Color(0xFFD0D0D0),
        fontFamily: 'Segoe UI', // Fuente típica de Windows
        visualDensity: VisualDensity.compact, // Interfaz densa de escritorio
        iconTheme: const IconThemeData(size: 16, color: Color(0xFF555555)),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 12, color: Colors.black87),
          bodySmall: TextStyle(fontSize: 11, color: Colors.black54),
          titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ---------------------------------------------------------------------------
// ESTRUCTURA PRINCIPAL (SHELL)
// ---------------------------------------------------------------------------
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Estado del Árbol
  List<SystemObject> _treeData = [];
  bool _isLoading = true;

  /// Opciones base disponibles en los menús contextuales del árbol
  static const List<_CreateAction> _baseCreateActions = [
    _CreateAction(
      label: 'Nueva carpeta',
      type: 'folder',
      description: 'Carpeta para organizar objetos',
    ),
    _CreateAction(
      label: 'Nuevo programa',
      type: 'program',
      description: 'Programa o script de control',
    ),
    _CreateAction(
      label: 'Nuevo script',
      type: 'script',
      description: 'Script asociado al servidor',
    ),
    _CreateAction(
      label: 'Nuevo gráfico',
      type: 'Graphic',
      description: 'Pantalla o gráfico vinculado a un screen',
    ),
  ];

  // Estado de las Pestañas (Work area)
  final List<SystemObject> _openTabs = [];
  int _selectedTabIndex = 0;

  // Objeto seleccionado actualmente (para el panel de propiedades)
  SystemObject? _selectedObject;

  @override
  void initState() {
    super.initState();
    _fetchSystemTree();
  }

  /// Obtiene los datos del backend y los organiza en árbol
  Future<void> _fetchSystemTree() async {
    try {
      // Intentamos conectar al backend real
      final response = await http.get(Uri.parse('$apiBaseUrl/system-objects'));

      if (response.statusCode == 200) {
        final List<dynamic> rawData = json.decode(response.body);
        final List<SystemObject> allObjects =
            rawData.map((e) => SystemObject.fromJson(e)).toList();
        setState(() {
          _treeData = _buildTree(allObjects);
          _isLoading = false;
        });
      } else {
        throw Exception('Error API');
      }
    } catch (e) {
      print("Error conectando al backend: $e");
      // DATA MOCKUP DE RESPALDO (Si el backend no corre localmente)
      setState(() {
        _treeData = _getMockData();
        _isLoading = false;
      });
    }
  }

  List<SystemObject> _buildTree(List<SystemObject> flatList) {
    // Algoritmo simple para convertir lista plana en árbol
    final Map<int, SystemObject> map = {
      for (var item in flatList) item.id: item
    };
    final List<SystemObject> roots = [];

    for (var item in flatList) {
      if (item.parentId == null) {
        roots.add(item);
      } else {
        if (map.containsKey(item.parentId)) {
          map[item.parentId]!.children.add(item);
        }
      }
    }
    return roots;
  }

  // Datos falsos para visualización si falla el backend
  List<SystemObject> _getMockData() {
    var server =
        SystemObject(id: 1, name: 'SmartStruxure Server', type: 'Server');
    var folderIo =
        SystemObject(id: 2, name: 'IO Bus', type: 'Folder', parentId: 1);
    var script = SystemObject(
        id: 3, name: 'HVAC Control Script', type: 'Script', parentId: 1);
    var graphics =
        SystemObject(id: 4, name: 'Floor Plan 1', type: 'Graphic', parentId: 1);

    server.children.addAll([folderIo, script, graphics]);
    server.isExpanded = true;
    return [server];
  }

  void _onObjectDoubleTap(SystemObject obj) {
    if (!_openTabs.contains(obj)) {
      setState(() {
        _openTabs.add(obj);
        _selectedTabIndex = _openTabs.length - 1;
        _selectedObject = obj;
      });
    } else {
      setState(() {
        _selectedTabIndex = _openTabs.indexOf(obj);
        _selectedObject = obj;
      });
    }
  }

  void _onObjectTap(SystemObject obj) {
    setState(() {
      _selectedObject = obj;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 1. HEADER / RIBBON BAR
          const EboRibbonBar(),

          // 2. MAIN BODY (3 Panes)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PANEL IZQUIERDO: SYSTEM TREE
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      const PanelHeader(title: 'System Tree'),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ListView(
                                  children: _treeData
                                      .map((node) => _buildTreeNode(node, 0))
                                      .toList(),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const VerticalDivider(
                    width: 1, thickness: 1, color: Color(0xFFC0C0C0)),

                // PANEL CENTRAL: WORKSPACE / TABS
                Expanded(
                  child: Column(
                    children: [
                      // Área de Tabs
                      Container(
                        height: 30,
                        color: const Color(0xFFE0E0E0),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _openTabs.length,
                          itemBuilder: (context, index) {
                            final obj = _openTabs[index];
                            final isSelected = index == _selectedTabIndex;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedTabIndex = index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFFE0E0E0),
                                  border: Border(
                                    right: const BorderSide(
                                        color: Colors.grey, width: 0.5),
                                    top: isSelected
                                        ? const BorderSide(
                                            color: Colors.green, width: 2)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _getIconForType(obj.type, size: 14),
                                    const SizedBox(width: 5),
                                    Text(obj.name,
                                        style: const TextStyle(fontSize: 11)),
                                    const SizedBox(width: 5),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _openTabs.removeAt(index);
                                          if (_selectedTabIndex >=
                                              _openTabs.length) {
                                            _selectedTabIndex =
                                                _openTabs.isEmpty
                                                    ? 0
                                                    : _openTabs.length - 1;
                                          }
                                        });
                                      },
                                      child: const Icon(Icons.close, size: 12),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Contenido de la Tab seleccionada
                      Expanded(
                        child: Container(
                          color: const Color(0xFFF5F5F5),
                          child: _openTabs.isEmpty
                              ? const Center(
                                  child: Text("Select an object to edit",
                                      style: TextStyle(color: Colors.grey)))
                              : _buildEditorContent(
                                  _openTabs[_selectedTabIndex]),
                        ),
                      ),
                    ],
                  ),
                ),

                const VerticalDivider(
                    width: 1, thickness: 1, color: Color(0xFFC0C0C0)),

                // PANEL DERECHO: PROPERTIES
                SizedBox(
                  width: 250,
                  child: Column(
                    children: [
                      const PanelHeader(title: 'Properties'),
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(8.0),
                          child: _selectedObject == null
                              ? const Text("No selection")
                              : _buildPropertyGrid(_selectedObject!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. STATUS BAR
          Container(
            height: 24,
            color: const Color(0xFF333333),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: Text(
              _selectedObject != null
                  ? "Selected: ${_selectedObject!.name} (ID: ${_selectedObject!.id})"
                  : "Ready",
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widgets Auxiliares de la UI ---

  Widget _buildTreeNode(SystemObject node, int depth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _onObjectTap(node),
          onDoubleTap: () => _onObjectDoubleTap(node),
          onSecondaryTapDown: (details) =>
              _showContextMenu(node, details.globalPosition),
          child: Container(
            color: _selectedObject == node
                ? const Color(0xFFCCE8FF)
                : Colors.transparent,
            padding:
                EdgeInsets.only(left: 4.0 + (depth * 16.0), top: 2, bottom: 2),
            child: Row(
              children: [
                if (node.children.isNotEmpty)
                  InkWell(
                    onTap: () {
                      setState(() {
                        node.isExpanded = !node.isExpanded;
                      });
                    },
                    child: Icon(
                        node.isExpanded
                            ? Icons.arrow_drop_down
                            : Icons.arrow_right,
                        size: 16),
                  )
                else
                  const SizedBox(width: 16),
                _getIconForType(node.type),
                const SizedBox(width: 6),
                Text(node.name, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
        if (node.isExpanded)
          ...node.children.map((child) => _buildTreeNode(child, depth + 1)),
      ],
    );
  }

  List<_CreateAction> _getContextActions(SystemObject node) {
    final nodeType = node.type.toLowerCase();
    if (nodeType != 'server' && nodeType != 'folder') {
      return const <_CreateAction>[];
    }

    // Ajustamos el menú según el nombre de la carpeta para dar acciones relevantes
    final normalizedName = node.name.toLowerCase();
    final List<_CreateAction> actions = [
      _baseCreateActions.first,
    ];

    if (nodeType == 'server' || normalizedName.contains('program')) {
      actions.add(_baseCreateActions[1]);
    }
    if (nodeType == 'server' || normalizedName.contains('script')) {
      actions.add(_baseCreateActions[2]);
    }
    if (nodeType == 'server' || normalizedName.contains('graphic')) {
      actions.add(_baseCreateActions[3]);
    }

    return actions;
  }

  Future<void> _showContextMenu(SystemObject node, Offset position) async {
    final actions = _getContextActions(node);
    final entries = <PopupMenuEntry<dynamic>>[
      PopupMenuItem(
        value: 'rename',
        child: const Text('Renombrar objeto'),
      ),
      if (actions.isNotEmpty) const PopupMenuDivider(),
      ...actions
          .map(
            (action) => PopupMenuItem<_CreateAction>(
              value: action,
              child: Text(action.label),
            ),
          )
          .toList(),
    ];

    final selected = await showMenu<dynamic>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: entries,
    );

    if (selected == 'rename') {
      _promptRename(node);
    } else if (selected is _CreateAction) {
      await _createSystemObject(node, selected);
    }
  }

  Future<void> _createSystemObject(
      SystemObject parent, _CreateAction action) async {
    final name = await _promptForName(
      title: 'Nombre para ${action.label}',
      initialValue: action.label,
    );

    if (name == null || name.trim().isEmpty) return;

    final payload = {
      'parent_id': parent.id,
      'name': name.trim(),
      'type': action.type,
      'description': action.description,
      'properties': action.properties ?? <String, dynamic>{},
    };

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/system-objects'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final created = SystemObject.fromJson({
          'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch,
          'parent_id': parent.id,
          'name': data['name'] ?? payload['name'],
          'type': data['type'] ?? payload['type'],
          'properties': data['properties'] ?? payload['properties'],
        });

        setState(() {
          _attachChildToTree(parent.id, created);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${action.label} creado en ${parent.name}')),
        );
      } else {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      // Fallback local cuando no hay backend: añade el objeto de manera temporal
      final localObj = SystemObject(
        id: DateTime.now().millisecondsSinceEpoch,
        parentId: parent.id,
        name: '$name (local)',
        type: action.type,
        properties: action.properties ?? {},
      );

      setState(() {
        _attachChildToTree(parent.id, localObj);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Creado en modo local por falta de conexión: ${action.label}'),
        ),
      );
    }
  }

  bool _attachChildToTree(int parentId, SystemObject child,
      [List<SystemObject>? nodes]) {
    final list = nodes ?? _treeData;
    for (final node in list) {
      if (node.id == parentId) {
        node.children.add(child);
        node.isExpanded = true;
        return true;
      }
      if (_attachChildToTree(parentId, child, node.children)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _promptRename(SystemObject obj) async {
    final newName = await _promptForName(
      title: 'Renombrar "${obj.name}"',
      initialValue: obj.name,
    );

    if (newName == null || newName.trim().isEmpty || newName == obj.name) {
      return;
    }

    await _renameSystemObject(obj, newName.trim());
  }

  Future<String?> _promptForName({
    required String title,
    required String initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Aceptar'),
            )
          ],
        );
      },
    );
  }

  Future<void> _renameSystemObject(SystemObject obj, String newName) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/system-objects/${obj.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': newName}),
      );

      if (response.statusCode != 200) {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No se pudo actualizar en el servidor ($e). El cambio es local.'),
        ),
      );
    } finally {
      setState(() {
        _updateObjectNameInTree(obj.id, newName);
      });
    }
  }

  bool _updateObjectNameInTree(int id, String newName,
      [List<SystemObject>? nodes]) {
    final list = nodes ?? _treeData;
    for (final node in list) {
      if (node.id == id) {
        node.name = newName;
        if (_selectedObject?.id == id) {
          _selectedObject = node;
        }
        for (var i = 0; i < _openTabs.length; i++) {
          if (_openTabs[i].id == id) {
            _openTabs[i].name = newName;
          }
        }
        return true;
      }
      if (_updateObjectNameInTree(id, newName, node.children)) {
        return true;
      }
    }
    return false;
  }

  Widget _buildEditorContent(SystemObject obj) {
    final type = obj.type.toLowerCase();
    if (type == 'script' || type == 'program') {
      return const ScriptEditorView();
    } else if (type == 'graphic' || type == 'screen') {
      return GraphicsEditorView(systemObject: obj);
    }
    return Center(child: Text("Generic Editor for ${obj.name}"));
  }

  Widget _buildPropertyGrid(SystemObject obj) {
    final nameController = TextEditingController(text: obj.name);
    return ListView(
      key: ValueKey(obj.id),
      children: [
        const Text(
          'Propiedades básicas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => _handlePropertyRename(obj, value),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Guardar nombre'),
            onPressed: () => _handlePropertyRename(obj, nameController.text),
          ),
        ),
        const Divider(),
        _propRow("Type", obj.type),
        _propRow("ID", obj.id.toString()),
        _propRow("Description", "System Object Node"),
        const Divider(),
        const Text("Advanced",
            style:
                TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        _propRow("Enabled", "True"),
        _propRow("Log Level", "Information"),
      ],
    );
  }

  void _handlePropertyRename(SystemObject obj, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío.')),
      );
      return;
    }
    if (trimmed == obj.name) return;
    _renameSystemObject(obj, trimmed);
  }

  Widget _propRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child:
                  Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(
              flex: 3,
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Icon _getIconForType(String type, {double size = 16}) {
    switch (type.toLowerCase()) {
      case 'server':
        return Icon(Icons.dns, color: Colors.blueAccent, size: size);
      case 'folder':
        return Icon(Icons.folder,
            color: const Color(0xFFEBC85E), size: size); // Amarillo carpeta
      case 'script':
      case 'program':
        return Icon(Icons.description, color: Colors.green, size: size);
      case 'graphic':
      case 'screen':
        return Icon(Icons.image, color: Colors.purple, size: size);
      default:
        return Icon(Icons.insert_drive_file, size: size);
    }
  }
}

class _CreateAction {
  final String label;
  final String type;
  final String description;
  final Map<String, dynamic>? properties;

  const _CreateAction({
    required this.label,
    required this.type,
    required this.description,
    this.properties,
  });
}

// ---------------------------------------------------------------------------
// WIDGETS DE ESTILO ESPECÍFICO EBO
// ---------------------------------------------------------------------------

class PanelHeader extends StatelessWidget {
  final String title;
  const PanelHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFEFEF), Color(0xFFD0D0D0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      width: double.infinity,
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }
}

class EboRibbonBar extends StatelessWidget {
  const EboRibbonBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80, // Altura típica de Ribbon
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey)),
      ),
      child: Column(
        children: [
          // Fila de Tabs del Ribbon (File, Edit, View...)
          Container(
            height: 25,
            color: const Color(0xFFF5F5F5),
            child: Row(
              children: [
                _ribbonTab("File", true),
                _ribbonTab("Edit", false),
                _ribbonTab("View", false),
                _ribbonTab("Actions", false),
                _ribbonTab("Window", false),
                _ribbonTab("Help", false),
              ],
            ),
          ),
          // Fila de Herramientas (Iconos)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ribbonButton(Icons.save, "Save"),
                  _ribbonButton(Icons.refresh, "Refresh"),
                  const VerticalDivider(),
                  _ribbonButton(Icons.cut, "Cut"),
                  _ribbonButton(Icons.copy, "Copy"),
                  _ribbonButton(Icons.paste, "Paste"),
                  const VerticalDivider(),
                  _ribbonButton(Icons.play_arrow, "Start"),
                  _ribbonButton(Icons.stop, "Stop"),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _ribbonTab(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: isSelected ? Colors.white : Colors.transparent,
      alignment: Alignment.center,
      child: Text(text,
          style: TextStyle(
              color: isSelected ? Colors.black : Colors.black54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
    );
  }

  Widget _ribbonButton(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF444444)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VISTAS DE EDITORES (MOCKUPS VISUALES)
// ---------------------------------------------------------------------------

// Editor de Scripts (Estilo EBO)
class ScriptEditorView extends StatelessWidget {
  const ScriptEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          color: Colors.white,
          child: Row(
            children: const [
              Icon(Icons.check, size: 16, color: Colors.green),
              SizedBox(width: 4),
              Text("Compilation OK",
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
              Spacer(),
              Text("Line 1, Col 1", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            alignment: Alignment.topLeft,
            child: const Text(
              "Numeric Input1, Input2\nNumeric Output\n\n  Output = Input1 + Input2\n  print(Output)\n\nEnd",
              style: TextStyle(
                  fontFamily: 'Courier New', fontSize: 13, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// Editor de Gráficos (Estilo EBO)
class GraphicsEditorView extends StatefulWidget {
  final SystemObject systemObject;
  const GraphicsEditorView({super.key, required this.systemObject});

  @override
  State<GraphicsEditorView> createState() => _GraphicsEditorViewState();
}

class _GraphicsEditorViewState extends State<GraphicsEditorView> {
  List<Screen> _screens = [];
  List<GraphicWidget> _widgets = [];
  Screen? _selectedScreen;
  GraphicWidget? _selectedWidget;
  bool _loadingScreens = true;
  bool _loadingWidgets = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _xCtrl = TextEditingController();
  final _yCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _configCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadScreenForTab();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    _xCtrl.dispose();
    _yCtrl.dispose();
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _configCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadScreenForTab() async {
    setState(() {
      _loadingScreens = true;
      _error = null;
    });
    try {
      Screen? initial;
      final targetId = widget.systemObject.screenId;
      final targetRoute = widget.systemObject.screenRoute;

      if (targetId != null) {
        final response =
            await http.get(Uri.parse('$apiBaseUrl/screens/$targetId'));
        if (response.statusCode != 200) {
          throw Exception(
              'Error al cargar la pantalla (${response.statusCode})');
        }
        initial = Screen.fromJson(jsonDecode(response.body));
      } else if (targetRoute != null) {
        final response =
            await http.get(Uri.parse('$apiBaseUrl/screens?route=$targetRoute'));
        if (response.statusCode != 200) {
          throw Exception(
              'Error al cargar la pantalla (${response.statusCode})');
        }
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          initial = Screen.fromJson(data.first);
        }
      }

      setState(() {
        _selectedScreen = initial;
        _screens = initial != null ? [initial] : [];
        _loadingScreens = false;
      });

      if (initial != null) {
        await _loadWidgets(initial.id, allowMock: true);
      }
    } catch (e) {
      final mockScreens = _buildMockScreens();
      setState(() {
        _screens = mockScreens;
        _selectedScreen = mockScreens.isNotEmpty ? mockScreens.first : null;
        _loadingScreens = false;
        _error = 'No se pudieron cargar las pantallas: $e. '
            'Se muestran datos de ejemplo.';
      });

      if (_selectedScreen != null) {
        await _loadWidgets(_selectedScreen!.id, allowMock: true);
      }
    }
  }

  Future<void> _loadWidgets(int screenId, {bool allowMock = false}) async {
    setState(() {
      _loadingWidgets = true;
      _error = null;
    });
    try {
      final response =
          await http.get(Uri.parse('$apiBaseUrl/screens/$screenId/widgets'));
      if (response.statusCode != 200) {
        throw Exception('Error al cargar widgets (${response.statusCode})');
      }
      final List<dynamic> data = jsonDecode(response.body);
      final widgets = data.map((e) => GraphicWidget.fromJson(e)).toList();

      setState(() {
        _widgets = widgets;
        _selectedWidget = widgets.isEmpty ? null : widgets.first;
      });
      if (widgets.isNotEmpty) {
        _fillForm(widgets.first);
      }
    } catch (e) {
      if (allowMock) {
        final mockWidgets = _buildMockWidgets(screenId);
        setState(() {
          _widgets = mockWidgets;
          _selectedWidget = mockWidgets.isEmpty ? null : mockWidgets.first;
          _error = 'No se pudieron cargar los widgets: $e. '
              'Se muestran datos de ejemplo.';
        });
      } else {
        setState(() {
          _error = 'No se pudieron cargar los widgets: $e';
        });
      }
    } finally {
      setState(() {
        _loadingWidgets = false;
      });
    }
  }

  Future<void> _createWidget() async {
    if (_selectedScreen == null) return;
    final screenId = _selectedScreen!.id;
    final payload = {
      'type': 'Panel',
      'name': 'Nuevo Widget',
      'x': 40,
      'y': 40,
      'width': 160,
      'height': 80,
      'config_json': {'note': 'Edita las propiedades y guarda'},
    };

    final response = await http.post(
      Uri.parse('$apiBaseUrl/screens/$screenId/widgets'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201) {
      await _loadWidgets(screenId, allowMock: true);
    } else {
      setState(() {
        _error = 'No se pudo crear el widget (${response.statusCode})';
      });
    }
  }

  Future<void> _saveWidget() async {
    final widget = _selectedWidget;
    final screen = _selectedScreen;
    if (widget == null || screen == null) return;

    final parsedConfig = _safeParseConfig(_configCtrl.text, widget.config);

    final payload = {
      'id': widget.id,
      'screen_id': screen.id,
      'type': _typeCtrl.text.trim().isEmpty ? widget.type : _typeCtrl.text,
      'name': _nameCtrl.text.trim().isEmpty ? widget.name : _nameCtrl.text,
      'x': int.tryParse(_xCtrl.text) ?? widget.x,
      'y': int.tryParse(_yCtrl.text) ?? widget.y,
      'width': int.tryParse(_widthCtrl.text) ?? widget.width,
      'height': int.tryParse(_heightCtrl.text) ?? widget.height,
      'config_json': parsedConfig,
    };

    final response = await http.put(
      Uri.parse('$apiBaseUrl/widgets/${widget.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      await _loadWidgets(screen.id, allowMock: true);
    } else {
      setState(() {
        _error = 'Error guardando el widget (${response.statusCode})';
      });
    }
  }

  Future<void> _deleteWidget() async {
    final widget = _selectedWidget;
    final screen = _selectedScreen;
    if (widget == null || screen == null) return;

    final response =
        await http.delete(Uri.parse('$apiBaseUrl/widgets/${widget.id}'));
    if (response.statusCode == 204) {
      await _loadWidgets(screen.id, allowMock: true);
    } else {
      setState(() {
        _error = 'No se pudo eliminar el widget (${response.statusCode})';
      });
    }
  }

  List<Screen> _buildMockScreens() {
    final mockId = widget.systemObject.screenId ?? 999;
    return [
      Screen(
        id: mockId,
        name: widget.systemObject.name,
        route: widget.systemObject.screenRoute ?? '/demo/${widget.systemObject.id}',
        description: 'Vista de ejemplo cuando no hay backend',
        enabled: true,
      ),
    ];
  }

  List<GraphicWidget> _buildMockWidgets(int screenId) {
    return [
      GraphicWidget(
        id: screenId * 1000 + 1,
        screenId: screenId,
        type: 'Panel',
        name: 'Panel de muestra',
        x: 30,
        y: 30,
        width: 180,
        height: 80,
        config: {'note': 'Sin backend, datos de ejemplo'},
      ),
      GraphicWidget(
        id: screenId * 1000 + 2,
        screenId: screenId,
        type: 'Value',
        name: 'Temperatura',
        x: 240,
        y: 120,
        width: 120,
        height: 70,
        config: {'label': 'Temp', 'value': '23.0°C'},
      ),
    ];
  }

  void _fillForm(GraphicWidget widget) {
    _nameCtrl.text = widget.name;
    _typeCtrl.text = widget.type;
    _xCtrl.text = widget.x.toString();
    _yCtrl.text = widget.y.toString();
    _widthCtrl.text = widget.width.toString();
    _heightCtrl.text = widget.height.toString();
    _configCtrl.text = const JsonEncoder.withIndent('  ').convert(widget.config);
  }

  Map<String, dynamic> _safeParseConfig(
      String value, Map<String, dynamic> fallback) {
    if (value.trim().isEmpty) return fallback;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      setState(() {
        _error = 'El JSON de config no es válido. Se mantendrá el valor previo.';
      });
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              const Text('Pantalla:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedScreen != null
                      ? '${_selectedScreen!.name} (${_selectedScreen!.route})'
                      : 'No se encontró la pantalla asociada',
                  style: TextStyle(
                    color: _selectedScreen != null
                        ? Colors.black
                        : Colors.red.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _loadingScreens ? null : _loadScreenForTab,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Recargar'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _selectedScreen == null || _loadingWidgets
                    ? null
                    : _createWidget,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar widget'),
              ),
              const Spacer(),
              if (_selectedScreen != null)
                Text('Ruta: ${_selectedScreen!.route}',
                    style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: Row(
            children: [
              SizedBox(
                width: 260,
                child: Card(
                  margin: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Widgets (${_widgets.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _loadingWidgets
                            ? const Center(child: CircularProgressIndicator())
                            : ListView.builder(
                                itemCount: _widgets.length,
                                itemBuilder: (context, index) {
                                  final widget = _widgets[index];
                                  final isSelected = widget.id == _selectedWidget?.id;
                                  return ListTile(
                                    selected: isSelected,
                                    selectedColor: Colors.green,
                                    selectedTileColor:
                                        Colors.green.withOpacity(0.1),
                                    title: Text(widget.name),
                                    subtitle: Text(
                                        '${widget.type} • (${widget.x},${widget.y})'),
                                    onTap: () {
                                      setState(() {
                                        _selectedWidget = widget;
                                      });
                                      _fillForm(widget);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEEEEE),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Stack(
                            children: [
                              GridPaper(
                                color: Colors.grey.withOpacity(0.3),
                                interval: 20,
                                divisions: 1,
                                subdivisions: 1,
                                child: Container(),
                              ),
                              ..._widgets.map(_buildWidgetShape),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildWidgetEditor()
                  ],
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildWidgetShape(GraphicWidget widget) {
    return Positioned(
      left: widget.x.toDouble(),
      top: widget.y.toDouble(),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedWidget = widget);
          _fillForm(widget);
        },
        child: Container(
          width: widget.width.toDouble(),
          height: widget.height.toDouble(),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color:
                  _selectedWidget?.id == widget.id ? Colors.green : Colors.black,
            ),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(1, 1)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
              Text(widget.type, style: const TextStyle(fontSize: 10)),
              const Spacer(),
              if (widget.config.isNotEmpty)
                Text(widget.config.toString(),
                    style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWidgetEditor() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Propiedades del widget',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _field('Name', _nameCtrl, width: 200),
              _field('Type', _typeCtrl, width: 140),
              _field('X', _xCtrl, width: 80, keyboard: TextInputType.number),
              _field('Y', _yCtrl, width: 80, keyboard: TextInputType.number),
              _field('Width', _widthCtrl, width: 80,
                  keyboard: TextInputType.number),
              _field('Height', _heightCtrl, width: 80,
                  keyboard: TextInputType.number),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Config JSON'),
          SizedBox(
            height: 120,
            child: TextField(
              controller: _configCtrl,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{"label": "Temp", "value": "23°C"}',
              ),
              style: const TextStyle(fontFamily: 'Courier New', fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _selectedWidget == null ? null : _saveWidget,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Guardar cambios'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _selectedWidget == null ? null : _deleteWidget,
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Eliminar'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {double width = 120, TextInputType keyboard = TextInputType.text}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
