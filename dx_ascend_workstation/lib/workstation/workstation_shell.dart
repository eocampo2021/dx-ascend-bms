import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/graphic_widget.dart';
import '../models/screen.dart';
import '../models/system_object.dart';
import 'api_config.dart';
import 'models/binding_assignment.dart';
import 'views/graphics_editor_view.dart';
import 'views/bindings_editor_view.dart';
import 'views/script_editor_view.dart';
import 'widgets/value_properties_editor.dart';
import 'widgets/ebo_ribbon_bar.dart';
import 'widgets/panel_header.dart';

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
      properties: const {'kind': 'digital', 'default': false},
    ),
    _CreateAction(
      label: 'Nuevo valor analógico',
      type: 'Analog Value',
      description: 'Punto analógico con valores numéricos',
      properties: const {'kind': 'analog', 'default': 0.0},
    ),
    _CreateAction(
      label: 'Nuevo valor de texto',
      type: 'String Value',
      description: 'Punto de texto para mensajes o etiquetas',
      properties: const {'kind': 'string', 'default': ''},
    ),
  ];

  // Estado de las Pestañas (Work area)
  final List<_EditorTab> _openTabs = [];
  int _selectedTabIndex = 0;

  // Estado del panel derecho y selección de widget en el editor gráfico
  bool _isRightPanelCollapsed = false;
  GraphicWidget? _selectedGraphicWidget;
  Widget? _widgetEditorPanel;

  // Objeto seleccionado actualmente (para el panel de propiedades)
  SystemObject? _selectedObject;
  int? _selectedListObjectId;

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
        _selectedGraphicWidget = null;
        _widgetEditorPanel = null;
        _selectedListObjectId = null;
      });
    } else {
      setState(() {
        _selectedTabIndex = index;
        _selectedObject = obj;
        if (!_isGraphicTab(_openTabs[index])) {
          _selectedGraphicWidget = null;
          _widgetEditorPanel = null;
        }
        _selectedListObjectId = null;
      });
    }
  }

  void _onObjectTap(SystemObject obj) {
    setState(() {
      _selectedObject = obj;
      _selectedListObjectId = null;
    });
  }

  void _onWidgetSelected(GraphicWidget? widget) {
    setState(() {
      _selectedGraphicWidget = widget;
    });
  }

  void _onWidgetEditorChanged(Widget? editor) {
    setState(() {
      _widgetEditorPanel = editor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _EditorTab? currentTab =
        _openTabs.isEmpty ? null : _openTabs[_selectedTabIndex];
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
                              onTap: () => setState(() {
                                _selectedTabIndex = index;
                                if (!_isGraphicTab(tab)) {
                                  _selectedGraphicWidget = null;
                                  _widgetEditorPanel = null;
                                }
                              }),
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

                _buildRightSidebar(currentTab),
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

  Future<void> _saveScriptSource(SystemObject obj, String code) async {
    final Map<String, dynamic> updatedProps = {
      ...obj.properties,
      'code': code,
    };

    await _saveObjectProperties(obj, updatedProps, 'Script guardado');
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
    if (type == 'folder') {
      return _buildFolderListView(obj);
    }
    if (type == 'script' || type == 'program') {
      return ScriptEditorView(
        key: ValueKey('script-${obj.id}'),
        systemObject: obj,
        onSave: (object, code) => _saveScriptSource(object, code),
        onCodeChanged: (code) => obj.properties['code'] = code,
      );
    } else if (type == 'graphic' || type == 'screen') {
      return GraphicsEditorView(
        key: ValueKey('graphic-${obj.id}'),
        systemObject: obj,
        availableValues: _collectValueObjects(),
        onWidgetSelected: _onWidgetSelected,
        onWidgetEditorChanged: _onWidgetEditorChanged,
      );
    }
    return Center(child: Text("Generic Editor for ${obj.name}"));
  }

  Widget _buildFolderListView(SystemObject folder) {
    final rows = folder.children;

    String _formatValue(SystemObject obj) {
      final props = obj.properties;
      final dynamic value = props['value'] ?? props['default'];
      if (value is num) return value.toString();
      if (value is bool) return value ? 'ON' : 'OFF';
      return value?.toString() ?? '-';
    }

    String _formatStatus(SystemObject obj) {
      final status = obj.properties['status'] ?? 'Enabled';
      return status.toString();
    }

    String _formatForce(SystemObject obj) {
      final force = obj.properties['forceStatus'] ?? obj.properties['force'];
      return (force ?? 'Not Forced').toString();
    }

    String _formatBinding(SystemObject obj) {
      final props = obj.properties;
      final hasBinding = props['bindingActive'] == true ||
          props['writingFromBinding'] == true ||
          props['valueFromBinding'] == true ||
          props['binding'] != null;
      return hasBinding ? 'Sí' : 'No';
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              title: Text('List View',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Objetos contenidos en la carpeta'),
            ),
            const Divider(height: 1),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text('La carpeta no contiene objetos'),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 720),
                        child: SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Nombre')),
                              DataColumn(label: Text('Descripción')),
                              DataColumn(label: Text('Valor')),
                              DataColumn(label: Text('Estado')),
                              DataColumn(label: Text('Forzado')),
                              DataColumn(label: Text('Bind')),
                            ],
                            rows: rows
                                .map(
                                  (child) => DataRow(
                                    selected: _selectedListObjectId == child.id,
                                    onSelectChanged: (_) {
                                      setState(() {
                                        _selectedListObjectId = child.id;
                                        _selectedObject = child;
                                      });
                                    },
                                    cells: [
                                      DataCell(Row(
                                        children: [
                                          _getIconForType(child.type),
                                          const SizedBox(width: 6),
                                          Text(child.name),
                                        ],
                                      )),
                                      DataCell(Text(
                                          child.properties['description']?.toString() ??
                                              child.type)),
                                      DataCell(Text(_formatValue(child))),
                                      DataCell(Text(_formatStatus(child))),
                                      DataCell(Text(_formatForce(child))),
                                      DataCell(Text(_formatBinding(child))),
                                    ],
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
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

  bool _isGraphicTab(_EditorTab tab) {
    final type = tab.object.type.toLowerCase();
    return type == 'graphic' || type == 'screen';
  }

  Widget _buildRightSidebar(_EditorTab? currentTab) {
    final isGraphic = currentTab != null && _isGraphicTab(currentTab);
    final selectedObj = _selectedObject ?? currentTab?.object;

    Widget buildPropertiesSection() {
      if (selectedObj == null) {
        return const Expanded(child: SizedBox.shrink());
      }
      return Expanded(
        flex: isGraphic ? 1 : 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Propiedades',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(child: _buildPropertyGrid(selectedObj)),
          ],
        ),
      );
    }

    Widget buildWidgetEditorSection() {
      if (!isGraphic) return const SizedBox.shrink();
      return Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Propiedades del widget',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _widgetEditorPanel ??
                  Card(
                    child: Center(
                      child: Text(
                        _selectedGraphicWidget == null
                            ? 'Selecciona un widget para ver y editar sus propiedades'
                            : 'Cargando editor...',
                      ),
                    ),
                  ),
            ),
          ],
        ),
      );
    }

    final content = selectedObj == null
        ? const Center(child: Text('No selection'))
        : Column(
            children: [
              buildPropertiesSection(),
              if (isGraphic) const SizedBox(height: 8),
              if (isGraphic) buildWidgetEditorSection(),
            ],
          );

    final panel = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isRightPanelCollapsed ? 14 : 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(left: BorderSide(color: Color(0xFFC0C0C0))),
        boxShadow: _isRightPanelCollapsed
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(-2, 0))
              ],
      ),
      child: _isRightPanelCollapsed
          ? InkWell(
              onTap: () => setState(() => _isRightPanelCollapsed = false),
              child: Center(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: Icon(Icons.chevron_left,
                      color: Colors.grey.shade600, size: 16),
                ),
              ),
            )
          : Column(
              children: [
                Container(
                  color: const Color(0xFFE0E0E0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      const Text('Panel derecho',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 18),
                        tooltip: 'Minimizar',
                        onPressed: () =>
                            setState(() => _isRightPanelCollapsed = true),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: content,
                  ),
                ),
              ],
            ),
    );

    return panel;
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
