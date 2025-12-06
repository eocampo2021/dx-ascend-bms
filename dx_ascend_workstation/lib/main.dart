import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Configuración de conexión al Backend existente
const String apiBaseUrl = 'http://localhost:3000/api';

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
// MODELOS DE DATOS (Coinciden con tu Schema.sql)
// ---------------------------------------------------------------------------
class SystemObject {
  final int id;
  final String name;
  final String type; // 'Folder', 'Server', 'Script', 'Graphic'
  final int? parentId;
  List<SystemObject> children = [];
  bool isExpanded = false;

  SystemObject({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
  });

  factory SystemObject.fromJson(Map<String, dynamic> json) {
    return SystemObject(
      id: json['id'],
      name: json['name'],
      type: json['type'] ?? 'Unknown',
      parentId: json[
          'ParentId'], // Nota: Revisa si tu JSON usa PascalCase o camelCase
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
        InkWell(
          onTap: () => _onObjectTap(node),
          onDoubleTap: () => _onObjectDoubleTap(node),
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

  Widget _buildEditorContent(SystemObject obj) {
    if (obj.type == 'Script') {
      return const ScriptEditorView();
    } else if (obj.type == 'Graphic') {
      return const GraphicsEditorView();
    }
    return Center(child: Text("Generic Editor for ${obj.type}"));
  }

  Widget _buildPropertyGrid(SystemObject obj) {
    // Simulación de tabla de propiedades
    return ListView(
      children: [
        _propRow("Name", obj.name),
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
    switch (type) {
      case 'Server':
        return Icon(Icons.dns, color: Colors.blueAccent, size: size);
      case 'Folder':
        return Icon(Icons.folder,
            color: const Color(0xFFEBC85E), size: size); // Amarillo carpeta
      case 'Script':
        return Icon(Icons.description, color: Colors.green, size: size);
      case 'Graphic':
        return Icon(Icons.image, color: Colors.purple, size: size);
      default:
        return Icon(Icons.insert_drive_file, size: size);
    }
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
class GraphicsEditorView extends StatelessWidget {
  const GraphicsEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fondo de cuadrícula
        Container(
          color: const Color(0xFFEEEEEE),
          child: GridPaper(
            color: Colors.grey.withOpacity(0.3),
            interval: 20,
            divisions: 1,
            subdivisions: 1,
            child: Container(),
          ),
        ),
        // Elementos simulados
        Positioned(
          left: 50,
          top: 50,
          child: Container(
            width: 100,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Column(
              children: [
                Container(
                    color: Colors.blue,
                    height: 20,
                    width: double.infinity,
                    child: const Center(
                        child: Text("AHU-1",
                            style:
                                TextStyle(color: Colors.white, fontSize: 10)))),
                const Expanded(
                    child: Center(
                        child: Icon(Icons.ac_unit,
                            size: 30, color: Colors.blueGrey))),
              ],
            ),
          ),
        ),
        Positioned(
          left: 200,
          top: 150,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black),
            ),
            child: const Center(
                child: Text("23.5°C",
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ),
        ),
      ],
    );
  }
}
