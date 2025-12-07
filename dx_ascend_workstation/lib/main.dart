import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  static const List<_CreateAction> _valueCreateActions = [
    _CreateAction(
      label: 'Nuevo valor digital',
      type: 'Digital Value',
      description: 'Punto digital para estados ON/OFF',
      properties: {'kind': 'digital', 'default': false},
    ),
    _CreateAction(
      label: 'Nuevo valor analógico',
      type: 'Analog Value',
      description: 'Punto analógico con valores numéricos',
      properties: {'kind': 'analog', 'default': 0.0},
    ),
    _CreateAction(
      label: 'Nuevo valor de texto',
      type: 'String Value',
      description: 'Punto de texto para mensajes o etiquetas',
      properties: {'kind': 'string', 'default': ''},
    ),
  ];

  // Estado de las Pestañas (Work area)
  final List<_EditorTab> _openTabs = [];
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
    var valuesFolder =
        SystemObject(id: 5, name: 'Values', type: 'Folder', parentId: 1);
    var digitalValue = SystemObject(
      id: 6,
      name: 'Fan Command',
      type: 'Digital Value',
      parentId: 5,
      properties: {'kind': 'digital', 'default': false},
    );
    var analogValue = SystemObject(
      id: 7,
      name: 'Supply Temp',
      type: 'Analog Value',
      parentId: 5,
      properties: {'kind': 'analog', 'default': 21.0, 'units': '°C'},
    );
    var stringValue = SystemObject(
      id: 8,
      name: 'Alarm Message',
      type: 'String Value',
      parentId: 5,
      properties: {'kind': 'string', 'default': 'OK'},
    );

    valuesFolder.children.addAll([digitalValue, analogValue, stringValue]);

    server.children.addAll([folderIo, script, graphics, valuesFolder]);
    server.isExpanded = true;
    return [server];
  }

  void _onObjectDoubleTap(SystemObject obj) {
    _openEditorTab(obj);
  }

  void _openEditorTab(SystemObject obj, {bool bindings = false}) {
    final index = _openTabs.indexWhere(
        (tab) => tab.object.id == obj.id && tab.isBindings == bindings);

    if (index == -1) {
      setState(() {
        _openTabs.add(_EditorTab(object: obj, isBindings: bindings));
        _selectedTabIndex = _openTabs.length - 1;
        _selectedObject = obj;
      });
    } else {
      setState(() {
        _selectedTabIndex = index;
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
                            final tab = _openTabs[index];
                            final obj = tab.object;
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
                                    tab.isBindings
                                        ? const Icon(Icons.link,
                                            size: 14, color: Colors.blueGrey)
                                        : _getIconForType(obj.type, size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                        tab.isBindings
                                            ? '${obj.name} [Bindings]'
                                            : obj.name,
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
    final bool canCreateValues =
        node.type.toLowerCase() == 'server' || node.type.toLowerCase() == 'folder';
    final entries = <PopupMenuEntry<dynamic>>[
      PopupMenuItem(
        value: 'rename',
        child: const Text('Renombrar objeto'),
      ),
      PopupMenuItem(
        value: 'bindings',
        child: const Text('Editar bindings'),
      ),
      PopupMenuItem(
        value: 'delete',
        child: const Text('Eliminar objeto'),
      ),
      if (actions.isNotEmpty || canCreateValues) const PopupMenuDivider(),
      ...actions
          .map(
            (action) => PopupMenuItem<_CreateAction>(
              value: action,
              child: Text(action.label),
            ),
          )
          .toList(),
      if (canCreateValues)
        PopupMenuItem<_CreateAction>(
          padding: EdgeInsets.zero,
          child: PopupMenuButton<_CreateAction>(
            padding: EdgeInsets.zero,
            onSelected: (action) => Navigator.of(context).pop(action),
            itemBuilder: (context) => _valueCreateActions
                .map(
                  (valueAction) => PopupMenuItem<_CreateAction>(
                    value: valueAction,
                    child: Text(valueAction.label),
                  ),
                )
                .toList(),
            child: const ListTile(
              dense: true,
              leading: Icon(Icons.category_outlined),
              title: Text('Nuevo Value'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ),
    ];

    final selected = await showMenu<dynamic>(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      items: entries,
    );

    if (selected == 'rename') {
      _promptRename(node);
    } else if (selected == 'bindings') {
      _openEditorTab(node, bindings: true);
    } else if (selected == 'delete') {
      await _confirmDeleteSystemObject(node);
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
        final decoded = jsonDecode(response.body);
        final Map<String, dynamic> data = decoded is Map<String, dynamic>
            ? {...decoded}
            : <String, dynamic>{};

        data['parent_id'] ??= parent.id;
        data['name'] ??= payload['name'];
        data['type'] ??= payload['type'];
        data['properties'] ??= payload['properties'];

        final created = SystemObject.fromJson({
          'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch,
          ...data,
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

  Future<void> _confirmDeleteSystemObject(SystemObject obj) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar objeto'),
        content: Text(
            '¿Deseas eliminar "${obj.name}" y todos sus elementos contenidos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete),
            label: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteSystemObject(obj);
    }
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

  Future<void> _deleteSystemObject(SystemObject obj) async {
    String message = 'Objeto eliminado correctamente.';
    bool removedFromTree = false;

    try {
      final response =
          await http.delete(Uri.parse('$apiBaseUrl/system-objects/${obj.id}'));
      if (response.statusCode != 200 &&
          response.statusCode != 204 &&
          response.statusCode != 202) {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      message = 'No se pudo eliminar en el servidor ($e). El cambio es local.';
    } finally {
      setState(() {
        final removed = _removeSystemObjectFromTree(obj.id);
        if (removed != null) {
          removedFromTree = true;
          final removedIds = _collectIds(removed);
          _openTabs.removeWhere((tab) => removedIds.contains(tab.object.id));
          if (_selectedObject != null &&
              removedIds.contains(_selectedObject!.id)) {
            _selectedObject = null;
          }
          if (_selectedTabIndex >= _openTabs.length) {
            _selectedTabIndex =
                _openTabs.isNotEmpty ? _openTabs.length - 1 : 0;
          }
        }
      });

      if (!removedFromTree) {
        message = 'No se encontró el objeto en el árbol.';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  SystemObject? _removeSystemObjectFromTree(int id,
      [List<SystemObject>? nodes]) {
    final list = nodes ?? _treeData;
    for (var i = 0; i < list.length; i++) {
      final node = list[i];
      if (node.id == id) {
        return list.removeAt(i);
      }
      final removed = _removeSystemObjectFromTree(id, node.children);
      if (removed != null) {
        return removed;
      }
    }
    return null;
  }

  List<int> _collectIds(SystemObject node) {
    final ids = <int>[node.id];
    for (final child in node.children) {
      ids.addAll(_collectIds(child));
    }
    return ids;
  }

  List<SystemObject> _flattenTree([List<SystemObject>? nodes]) {
    final list = nodes ?? _treeData;
    final result = <SystemObject>[];
    for (final node in list) {
      result.add(node);
      result.addAll(_flattenTree(node.children));
    }
    return result;
  }

  bool _isValueType(String type) {
    final lower = type.toLowerCase();
    return lower == 'digital value' ||
        lower == 'analog value' ||
        lower == 'string value';
  }

  List<SystemObject> _collectValueObjects() {
    return _flattenTree().where((obj) => _isValueType(obj.type)).toList();
  }

  Future<void> _saveObjectProperties(SystemObject obj,
      Map<String, dynamic> properties, String successMessage) async {
    bool savedRemotely = true;
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/system-objects/${obj.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'properties': properties}),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Status ${response.statusCode}');
      }
    } catch (e) {
      savedRemotely = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No se pudieron guardar los cambios en el servidor ($e). Se conservarán localmente.'),
        ),
      );
    } finally {
      setState(() {
        _applyPropertiesToTree(obj.id, properties);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(savedRemotely
              ? successMessage
              : '$successMessage (solo en modo local)'),
        ),
      );
    }
  }

  Future<void> _updateObjectBindings(
      SystemObject obj, List<BindingAssignment> bindings) async {
    final bindingJson = bindings
        .where((binding) =>
            binding.target != null && binding.slot.trim().isNotEmpty)
        .map((binding) => binding.toJson())
        .toList();

    final Map<String, dynamic> updatedProps = {
      ...obj.properties,
      'bindings': bindingJson,
    };

    await _saveObjectProperties(obj, updatedProps, 'Bindings actualizados');
  }

  bool _applyPropertiesToTree(int id, Map<String, dynamic> properties,
      [List<SystemObject>? nodes]) {
    final list = nodes ?? _treeData;
    for (final node in list) {
      if (node.id == id) {
        node.properties
          ..clear()
          ..addAll(properties);
        if (_selectedObject?.id == id) {
          _selectedObject = node;
        }
        for (final tab in _openTabs.where((tab) => tab.object.id == id)) {
          tab.object.properties
            ..clear()
            ..addAll(properties);
        }
        return true;
      }
      if (_applyPropertiesToTree(id, properties, node.children)) {
        return true;
      }
    }
    return false;
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
          if (_openTabs[i].object.id == id) {
            _openTabs[i].object.name = newName;
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

  Widget _buildEditorContent(_EditorTab tab) {
    final obj = tab.object;
    if (tab.isBindings) {
      return BindingsEditorView(
        key: ValueKey('bindings-${obj.id}'),
        systemObject: obj,
        availableValues: _collectValueObjects(),
        onSave: (bindings) => _updateObjectBindings(obj, bindings),
      );
    }

    final type = obj.type.toLowerCase();
    if (type == 'script' || type == 'program') {
      return const ScriptEditorView();
    } else if (type == 'graphic' || type == 'screen') {
      return GraphicsEditorView(
        key: ValueKey('graphic-${obj.id}'),
        systemObject: obj,
        availableValues: _collectValueObjects(),
      );
    }
    return Center(child: Text("Generic Editor for ${obj.name}"));
  }

  Widget _buildPropertyGrid(SystemObject obj) {
    final nameController = TextEditingController(text: obj.name);
    final isValue = _isValueType(obj.type);
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
        if (isValue) ...[
          const Divider(),
          ValuePropertiesEditor(
            key: ValueKey('value-props-${obj.id}-${obj.properties.hashCode}'),
            object: obj,
            onSave: (properties) =>
                _saveObjectProperties(obj, properties, 'Propiedades del Value actualizadas'),
          ),
        ],
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
      case 'digital value':
        return Icon(Icons.toggle_on, color: Colors.blue, size: size);
      case 'analog value':
        return Icon(Icons.show_chart, color: Colors.orange, size: size);
      case 'string value':
        return Icon(Icons.short_text, color: Colors.teal, size: size);
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

class _EditorTab {
  final SystemObject object;
  final bool isBindings;

  _EditorTab({required this.object, this.isBindings = false});

  @override
  bool operator ==(Object other) {
    return other is _EditorTab &&
        other.object.id == object.id &&
        other.isBindings == isBindings;
  }

  @override
  int get hashCode => Object.hash(object.id, isBindings);
}

class ValuePropertiesEditor extends StatefulWidget {
  final SystemObject object;
  final Future<void> Function(Map<String, dynamic> properties) onSave;

  const ValuePropertiesEditor({
    super.key,
    required this.object,
    required this.onSave,
  });

  @override
  State<ValuePropertiesEditor> createState() => _ValuePropertiesEditorState();
}

class _ValuePropertiesEditorState extends State<ValuePropertiesEditor> {
  late String _status;
  late String _forceStatus;
  late bool _bindingActive;
  late bool _boolValue;
  late TextEditingController _numericController;
  late TextEditingController _stringController;

  @override
  void initState() {
    super.initState();
    _numericController = TextEditingController();
    _stringController = TextEditingController();
    _loadFromObject();
  }

  @override
  void didUpdateWidget(covariant ValuePropertiesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.object.id != widget.object.id ||
        !mapEquals(oldWidget.object.properties, widget.object.properties)) {
      _loadFromObject();
    }
  }

  @override
  void dispose() {
    _numericController.dispose();
    _stringController.dispose();
    super.dispose();
  }

  String get _kind {
    final propKind = widget.object.properties['kind'];
    if (propKind is String && propKind.isNotEmpty) {
      return propKind.toLowerCase();
    }
    final lowerType = widget.object.type.toLowerCase();
    if (lowerType.contains('digital')) return 'digital';
    if (lowerType.contains('analog')) return 'analog';
    return 'string';
  }

  bool get _isEnabled => _status.toLowerCase() == 'enabled';

  bool get _isForced => _forceStatus.toLowerCase() == 'forced';

  bool get _canEditValue => _isEnabled && (!_bindingActive || _isForced);

  void _loadFromObject() {
    final props = widget.object.properties;
    _status = (props['status'] ?? 'Enabled').toString();
    _forceStatus = (props['forceStatus'] ?? 'Not Forced').toString();
    _bindingActive = props['bindingActive'] == true ||
        props['writingFromBinding'] == true ||
        props['valueFromBinding'] == true;

    final dynamic rawValue = props['value'] ?? props['default'];
    switch (_kind) {
      case 'digital':
        _boolValue = rawValue is bool
            ? rawValue
            : (rawValue is num ? rawValue != 0 : false);
        break;
      case 'analog':
        final numValue = rawValue is num ? rawValue.toDouble() : 0.0;
        _numericController.text = numValue.toString();
        _boolValue = false;
        break;
      default:
        _stringController.text = (rawValue ?? '').toString();
        _boolValue = false;
    }
    setState(() {});
  }

  Widget _dropdown(
      String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          isDense: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: options
              .map((opt) => DropdownMenuItem<String>(
                    value: opt,
                    child: Text(opt),
                  ))
              .toList(),
          onChanged: (val) => setState(() => onChanged(val)),
        ),
      ],
    );
  }

  Widget _buildValueInput() {
    final labelStyle = TextStyle(
      color: _canEditValue ? Colors.black87 : Colors.grey.shade700,
      fontWeight: FontWeight.w600,
    );

    switch (_kind) {
      case 'digital':
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
            color: _canEditValue ? Colors.transparent : Colors.grey.shade200,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Valor', style: labelStyle),
              Switch(
                value: _boolValue,
                onChanged: _canEditValue
                    ? (val) => setState(() => _boolValue = val)
                    : null,
              ),
            ],
          ),
        );
      case 'analog':
        return TextField(
          controller: _numericController,
          enabled: _canEditValue,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Valor',
            isDense: true,
            filled: !_canEditValue,
            fillColor: Colors.grey.shade200,
            border: const OutlineInputBorder(),
          ),
        );
      default:
        return TextField(
          controller: _stringController,
          enabled: _canEditValue,
          decoration: InputDecoration(
            labelText: 'Valor',
            isDense: true,
            filled: !_canEditValue,
            fillColor: Colors.grey.shade200,
            border: const OutlineInputBorder(),
          ),
        );
    }
  }

  dynamic _currentValue() {
    switch (_kind) {
      case 'digital':
        return _boolValue;
      case 'analog':
        return double.tryParse(_numericController.text.trim()) ?? 0.0;
      default:
        return _stringController.text;
    }
  }

  Future<void> _save() async {
    final props = {
      ...widget.object.properties,
      'kind': _kind,
      'status': _status,
      'forceStatus': _forceStatus,
      'bindingActive': _bindingActive,
      'value': _currentValue(),
    };

    await widget.onSave(props);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Atributos del Value',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildValueInput(),
        if (_bindingActive && !_isForced)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              'Valor provisto por un Binding (solo lectura).',
              style: TextStyle(fontSize: 11, color: Colors.blueGrey),
            ),
          ),
        const SizedBox(height: 10),
        _dropdown('Estado', _status, const ['Enabled', 'Disabled'], (value) {
          _status = value ?? 'Enabled';
        }),
        const SizedBox(height: 10),
        _dropdown('Force Status', _forceStatus,
            const ['Forced', 'Not Forced'], (value) {
          _forceStatus = value ?? 'Not Forced';
        }),
        const SizedBox(height: 12),
        const Text(
          'En "Enabled" el valor puede cambiar por el operador o por Binding. En "Disabled" no se propagará ningún cambio.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        const Text(
          'Si está en "Forced", el operador sobrescribe cualquier Binding y el valor se envía a los objetos vinculados.',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Guardar cambios'),
            onPressed: _save,
          ),
        ),
      ],
    );
  }
}

class BindingAssignment {
  String slot;
  SystemObject? target;

  BindingAssignment({required this.slot, this.target});

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'valueId': target?.id,
        'valueName': target?.name,
        'valueType': target?.type,
      };

  static BindingAssignment fromJson(
      Map<String, dynamic> json, List<SystemObject> availableValues) {
    final slot = (json['slot'] ?? json['name'] ?? 'binding').toString();
    SystemObject? target;

    final idValue = json['valueId'] ?? json['targetId'];
    int? parsedId;
    if (idValue is int) parsedId = idValue;
    if (idValue is String) parsedId = int.tryParse(idValue);
    if (parsedId != null) {
      for (final value in availableValues) {
        if (value.id == parsedId) {
          target = value;
          break;
        }
      }
    }

    if (target == null && json['valueName'] is String) {
      final name = json['valueName'] as String;
      for (final value in availableValues) {
        if (value.name == name) {
          target = value;
          break;
        }
      }
    }

    return BindingAssignment(slot: slot, target: target);
  }
}

class BindingsEditorView extends StatefulWidget {
  final SystemObject systemObject;
  final List<SystemObject> availableValues;
  final Future<void> Function(List<BindingAssignment> bindings) onSave;

  const BindingsEditorView({
    super.key,
    required this.systemObject,
    required this.availableValues,
    required this.onSave,
  });

  @override
  State<BindingsEditorView> createState() => _BindingsEditorViewState();
}

class _BindingsEditorViewState extends State<BindingsEditorView> {
  late List<BindingAssignment> _bindings;

  @override
  void initState() {
    super.initState();
    _bindings = _loadBindingsFromObject();
  }

  @override
  void didUpdateWidget(covariant BindingsEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.availableValues.map((e) => e.id).toSet();
    final newIds = widget.availableValues.map((e) => e.id).toSet();
    if (!setEquals(oldIds, newIds)) {
      setState(() {
        _bindings = _loadBindingsFromObject();
      });
    }
  }

  List<BindingAssignment> _loadBindingsFromObject() {
    final rawBindings = widget.systemObject.properties['bindings'];
    if (rawBindings is List) {
      return rawBindings
          .whereType<Map<String, dynamic>>()
          .map((raw) => BindingAssignment.fromJson(raw, widget.availableValues))
          .toList();
    }
    return [];
  }

  void _addBinding() {
    setState(() {
      _bindings.add(BindingAssignment(
          slot: 'binding-${_bindings.length + 1}', target: null));
    });
  }

  Future<void> _saveBindings() async {
    await widget.onSave(_bindings);
    if (mounted) {
      setState(() {
        _bindings = _loadBindingsFromObject();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bindings de ${widget.systemObject.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Chip(
                avatar: const Icon(Icons.storage, size: 14),
                label: Text('${widget.availableValues.length} valores disponibles'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
              'Selecciona los valores que se vincularán a este objeto. Estos bindings podrán usarse en widgets de las pantallas.'),
          const SizedBox(height: 12),
          Expanded(
            child: _bindings.isEmpty
                ? const Center(
                    child: Text('No hay bindings configurados para este objeto.'),
                  )
                : ListView.separated(
                    itemCount: _bindings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _buildBindingRow(index),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _saveBindings,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Guardar bindings'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addBinding,
                icon: const Icon(Icons.add_link, size: 16),
                label: const Text('Agregar binding'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() {
                  _bindings = _loadBindingsFromObject();
                }),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Recargar'),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBindingRow(int index) {
    final binding = _bindings[index];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: binding.slot,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Etiqueta del binding',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => binding.slot = value,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _bindingDropdown(binding)),
                IconButton(
                  tooltip: 'Eliminar binding',
                  onPressed: () {
                    setState(() {
                      _bindings.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                )
              ],
            ),
            if (binding.target != null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Tipo: ${binding.target!.type} • ID: ${binding.target!.id}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.blueGrey),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _bindingDropdown(BindingAssignment binding) {
    return DropdownButtonFormField<SystemObject?>(
      value: binding.target,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        labelText: 'Valor vinculado',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<SystemObject?>(
          value: null,
          child: Text('Sin valor'),
        ),
        ...widget.availableValues.map(
          (value) => DropdownMenuItem<SystemObject?>(
            value: value,
            child: Text('${value.name} (${value.type})'),
          ),
        ),
      ],
      onChanged: (selected) {
        setState(() {
          binding.target = selected;
        });
      },
    );
  }
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
  final List<SystemObject> availableValues;
  const GraphicsEditorView(
      {super.key,
      required this.systemObject,
      required this.availableValues});

  @override
  State<GraphicsEditorView> createState() => _GraphicsEditorViewState();
}

class _GraphicsEditorViewState extends State<GraphicsEditorView> {
  List<Screen> _screens = [];
  List<GraphicWidget> _widgets = [];
  Screen? _selectedScreen;
  GraphicWidget? _selectedWidget;
  SystemObject? _selectedBindingValue;
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

  static const List<String> _widgetTypes = [
    'text',
    'bar',
    'gauge',
    'indicator',
    'button'
  ];
  String? _selectedWidgetType;

  @override
  void initState() {
    super.initState();
    _loadScreenForTab();
  }

  @override
  void didUpdateWidget(covariant GraphicsEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.systemObject.id != widget.systemObject.id ||
        oldWidget.systemObject.screenId != widget.systemObject.screenId ||
        oldWidget.systemObject.screenRoute != widget.systemObject.screenRoute ||
        oldWidget.systemObject.name != widget.systemObject.name) {
      setState(() {
        _selectedScreen = null;
        _widgets = [];
        _selectedWidget = null;
        _selectedWidgetType = null;
        _screens = [];
        _loadingWidgets = false;
        _error = null;
      });
      _loadScreenForTab();
    }

    final oldIds = oldWidget.availableValues.map((e) => e.id).toSet();
    final newIds = widget.availableValues.map((e) => e.id).toSet();
    if (!setEquals(oldIds, newIds) && _selectedWidget != null) {
      setState(() {
        _selectedBindingValue =
            _matchBindingFromConfig(_selectedWidget!.config);
      });
    }
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
        initial = await _fetchScreenById(targetId);
      }

      if (initial == null && targetRoute != null) {
        initial = await _fetchScreenByRoute(targetRoute);
      }

      if (initial == null) {
        initial = await _fetchScreenByName(widget.systemObject.name);
      }

      setState(() {
        _selectedScreen = initial;
        _screens = initial != null ? [initial] : [];
        _loadingScreens = false;
      });

      if (initial != null) {
        await _loadWidgets(initial.id, allowMock: true);
      } else {
        setState(() {
          _error = 'No se encontró ninguna pantalla asociada a este objeto.';
        });
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

  Future<Screen?> _fetchScreenById(int id) async {
    final response = await http.get(Uri.parse('$apiBaseUrl/screens/$id'));
    if (response.statusCode == 200) {
      return Screen.fromJson(jsonDecode(response.body));
    }
    return null;
  }

  Future<Screen?> _fetchScreenByRoute(String route) async {
    final response =
        await http.get(Uri.parse('$apiBaseUrl/screens?route=$route'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        return Screen.fromJson(data.first);
      }
    }
    return null;
  }

  Future<Screen?> _fetchScreenByName(String name) async {
    if (name.trim().isEmpty) return null;
    final response =
        await http.get(Uri.parse('$apiBaseUrl/screens?name=$name'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        return Screen.fromJson(data.first);
      }
    }
    return null;
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
        _selectedWidgetType =
            widgets.isEmpty ? null : _matchWidgetType(widgets.first.type);
        _selectedBindingValue = widgets.isEmpty
            ? null
            : _matchBindingFromConfig(widgets.first.config);
        if (widgets.isEmpty) {
          _nameCtrl.clear();
          _typeCtrl.clear();
          _xCtrl.clear();
          _yCtrl.clear();
          _widthCtrl.clear();
          _heightCtrl.clear();
          _configCtrl.clear();
        }
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
          _selectedWidgetType = mockWidgets.isEmpty
              ? null
              : _matchWidgetType(mockWidgets.first.type);
          _selectedBindingValue = mockWidgets.isEmpty
              ? null
              : _matchBindingFromConfig(mockWidgets.first.config);
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
      'type': _widgetTypes.first,
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
    final updatedConfig = Map<String, dynamic>.from(parsedConfig);
    if (_selectedBindingValue != null) {
      updatedConfig['binding'] = {
        'valueId': _selectedBindingValue!.id,
        'valueName': _selectedBindingValue!.name,
        'valueType': _selectedBindingValue!.type,
      };
    } else {
      updatedConfig.remove('binding');
    }

    final payload = {
      'id': widget.id,
      'screen_id': screen.id,
      'type': _typeCtrl.text.trim().isEmpty ? widget.type : _typeCtrl.text,
      'name': _nameCtrl.text.trim().isEmpty ? widget.name : _nameCtrl.text,
      'x': int.tryParse(_xCtrl.text) ?? widget.x,
      'y': int.tryParse(_yCtrl.text) ?? widget.y,
      'width': int.tryParse(_widthCtrl.text) ?? widget.width,
      'height': int.tryParse(_heightCtrl.text) ?? widget.height,
      'config_json': updatedConfig,
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
    final mockRoute =
        '/web/${widget.systemObject.name.replaceAll(' ', '').toLowerCase()}';
    return [
      Screen(
        id: mockId,
        name: widget.systemObject.name,
        route: widget.systemObject.screenRoute ?? mockRoute,
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
    _selectedWidgetType = _matchWidgetType(widget.type);
    _xCtrl.text = widget.x.toString();
    _yCtrl.text = widget.y.toString();
    _widthCtrl.text = widget.width.toString();
    _heightCtrl.text = widget.height.toString();
    _selectedBindingValue = _matchBindingFromConfig(widget.config);
    _configCtrl.text = const JsonEncoder.withIndent('  ').convert(widget.config);
    setState(() {});
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

  String? _matchWidgetType(String type) {
    for (final option in _widgetTypes) {
      if (option.toLowerCase() == type.toLowerCase()) {
        return option;
      }
    }
    return null;
  }

  SystemObject? _matchBindingFromConfig(Map<String, dynamic> config) {
    final binding = config['binding'];
    if (binding is Map<String, dynamic>) {
      final idValue = binding['valueId'] ?? binding['targetId'];
      int? targetId;
      if (idValue is int) targetId = idValue;
      if (idValue is String) targetId = int.tryParse(idValue);

      if (targetId != null) {
        for (final value in widget.availableValues) {
          if (value.id == targetId) return value;
        }
      }

      final name = binding['valueName'];
      if (name is String) {
        for (final value in widget.availableValues) {
          if (value.name == name) return value;
        }
      }
    }
    return null;
  }

  String? _formatBindingValue(SystemObject? target) {
    if (target == null) return null;
    final props = target.properties;
    dynamic value = props['value'] ?? props['default'];
    final unit = props['units'] ?? props['unit'];

    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) value = parsed;
    }

    if (value is num) {
      final decimals = value is int ? 0 : 1;
      final base = value.toStringAsFixed(decimals);
      if (unit != null && unit.toString().isNotEmpty) {
        return '$base ${unit.toString()}';
      }
      return base;
    }

    if (value is bool) return value ? 'ON' : 'OFF';
    return value?.toString();
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
    final binding = widget.config['binding'];
    final bindingLabel = binding is Map<String, dynamic>
        ? (binding['valueName'] ??
            binding['valueId']?.toString() ??
            binding['targetId']?.toString())
        : null;
    final bindingTarget = _matchBindingFromConfig(widget.config);
    final bindingValueLabel = _formatBindingValue(bindingTarget);
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
              if (bindingLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text('Binding: $bindingLabel',
                      style: const TextStyle(
                          fontSize: 9, color: Colors.blueGrey)),
                ),
              if (bindingValueLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text('Valor: $bindingValueLabel',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600)),
                ),
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
              _typeDropdown(),
              _field('X', _xCtrl, width: 80, keyboard: TextInputType.number),
              _field('Y', _yCtrl, width: 80, keyboard: TextInputType.number),
              _field('Width', _widthCtrl, width: 80,
                  keyboard: TextInputType.number),
              _field('Height', _heightCtrl, width: 80,
                  keyboard: TextInputType.number),
            ],
          ),
          const SizedBox(height: 8),
          _bindingDropdown(),
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

  Widget _typeDropdown() {
    final currentType = _typeCtrl.text.trim();
    final options = [..._widgetTypes];
    if (currentType.isNotEmpty &&
        !options
            .any((type) => type.toLowerCase() == currentType.toLowerCase())) {
      options.add(currentType);
    }

    String? value;
    for (final option in options) {
      if (option.toLowerCase() == currentType.toLowerCase()) {
        value = option;
        break;
      }
    }
    value ??= _selectedWidgetType;

    return SizedBox(
      width: 140,
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Type',
          border: OutlineInputBorder(),
        ),
        items: options
            .map((type) => DropdownMenuItem(value: type, child: Text(type)))
            .toList(),
        onChanged: (selected) {
          setState(() {
            _selectedWidgetType = selected;
            _typeCtrl.text = selected ?? '';
          });
        },
      ),
    );
  }

  Widget _bindingDropdown() {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<SystemObject?>(
        value: _selectedBindingValue,
        isExpanded: true,
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Binding (Value object)',
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<SystemObject?>(
            value: null,
            child: Text('Sin binding'),
          ),
          ...widget.availableValues.map(
            (value) => DropdownMenuItem<SystemObject?>(
              value: value,
              child: Text('${value.name} • ${value.type}'),
            ),
          ),
        ],
        onChanged: (selected) {
          setState(() {
            _selectedBindingValue = selected;
          });
        },
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
