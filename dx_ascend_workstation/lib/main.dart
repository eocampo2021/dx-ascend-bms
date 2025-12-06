import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'models/system_object.dart';
import 'screen_designer.dart'; // Importa ScreenDesigner (tu editor visual)
import 'script_editor.dart'; // Importa ScriptEditor (tu editor de código)

void main() {
  runApp(const AscendWorkstationApp());
}

class AscendWorkstationApp extends StatelessWidget {
  const AscendWorkstationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DX Ascend Workstation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF009E4D)),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const WorkstationShell(),
    );
  }
}

class WorkstationShell extends StatefulWidget {
  const WorkstationShell({super.key});

  @override
  State<WorkstationShell> createState() => _WorkstationShellState();
}

class _WorkstationShellState extends State<WorkstationShell> {
  List<SystemObject> _allObjects = [];
  SystemObject? _selectedObject;
  bool _isLoading = true;

  final String _apiUrl = 'http://localhost:3000/api/system-objects';

  @override
  void initState() {
    super.initState();
    _fetchSystemTree();
  }

  // --- API/Data Handling ---

  Future<void> _fetchSystemTree() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _allObjects = data.map((e) => SystemObject.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching tree: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveObject(int id, String name, String propertiesJson) async {
    try {
      await http.put(
        Uri.parse('$_apiUrl/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'name': name, 'properties': jsonDecode(propertiesJson)}),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved successfully")),
      );
      // No recargar el árbol si solo movimos un widget, para evitar parpadeos,
      // pero en una aplicación real, se debería hacer un "refresh state" más inteligente.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e")),
      );
    }
  }

  // --- Graphics Editor Logic (Custom for your ScreenDesigner) ---

  /// Maneja el callback de ScreenDesigner cuando un widget es movido o redimensionado.
  void _updateAndSaveScreenWidget(Map<String, dynamic> updatedWidget) {
    if (_selectedObject == null || _selectedObject!.type != 'screen') return;

    // 1. Obtener la lista de widgets del objeto actual
    Map<String, dynamic> props = jsonDecode(_selectedObject!.properties);
    List<dynamic> widgetsList = props['widgets'] ?? [];

    // 2. Encontrar y actualizar el widget por ID
    final int widgetId = (updatedWidget['id'] as num).toInt();
    int index = widgetsList.indexWhere((w) => w['id'] == widgetId);

    if (index != -1) {
      // Copiar el widget existente para modificarlo
      Map<String, dynamic> existingWidget = Map.from(widgetsList[index]);

      // Actualizar solo las propiedades de posición/tamaño (proporcionadas por ScreenDesigner)
      existingWidget['x'] = (updatedWidget['x'] as num).toDouble();
      existingWidget['y'] = (updatedWidget['y'] as num).toDouble();
      existingWidget['width'] = (updatedWidget['width'] as num).toDouble();
      existingWidget['height'] = (updatedWidget['height'] as num).toDouble();
      // Si hay otros campos en updatedWidget (como configJson), los fusionamos:
      // existingWidget.addAll(updatedWidget);

      widgetsList[index] = existingWidget;
    } else {
      // En este caso, el widget no existe, lo agregamos (útil para la función _addNewWidget)
      widgetsList.add(updatedWidget);
    }

    // 3. Re-serializar el JSON completo
    props['widgets'] = widgetsList;
    String newPropsJson = jsonEncode(props);

    // 4. Actualizar el modelo local (para que el widget se redibuje) y guardar en API
    setState(() {
      _selectedObject!.properties = newPropsJson;
    });

    _saveObject(_selectedObject!.id, _selectedObject!.name, newPropsJson);
  }

  /// Función auxiliar para simular la adición de un nuevo widget (solo para demo)
  void _addNewWidget(SystemObject screenObject) {
    Map<String, dynamic> props = jsonDecode(screenObject.properties);
    List<dynamic> widgetsList = props['widgets'] ?? [];

    // Simple ID: toma el máximo ID existente + 1
    int newId = widgetsList.isEmpty
        ? 1
        : (widgetsList.map((w) => w['id'] as int).reduce(max) + 1);

    // Crear un widget de ejemplo (Barra)
    final newWidget = {
      'id': newId,
      'name': 'Bar_CHWS_${newId}',
      'type': 'bar',
      'x': 50.0 + (newId % 4) * 150,
      'y': 50.0 + (newId % 4) * 100,
      'width': 120.0,
      'height': 60.0,
      'config_json': {
        'point': 'var_analog:CHWS_Temp'
      } // Asumimos un binding a una variable
    };

    // Usamos la misma función de update/save, lo agregará a la lista
    _updateAndSaveScreenWidget(newWidget);
  }

  // --- UI Builder Functions ---

  IconData _getIconForType(String type) {
    switch (type) {
      case 'server':
        return Icons.dns;
      case 'folder':
        return Icons.folder;
      case 'program':
        return Icons.code;
      case 'screen':
        return Icons.monitor;
      case 'device_modbus':
        return Icons.settings_input_component;
      case 'var_analog':
        return Icons.show_chart;
      case 'var_digital':
        return Icons.toggle_on;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildTreeNode(Map<String, dynamic> node) {
    IconData icon;
    Color iconColor = Colors.grey;

    // ... (Lógica de iconos)

    switch (node['type']) {
      case 'server':
        icon = Icons.dns;
        iconColor = Colors.blue;
        break;
      case 'folder':
        icon = Icons.folder;
        iconColor = const Color(0xFFE67E22);
        break;
      case 'program':
        icon = Icons.code;
        iconColor = Colors.purple;
        break;
      case 'screen':
        icon = Icons.monitor;
        iconColor = Colors.teal;
        break;
      case 'device_modbus':
        icon = Icons.settings_input_component;
        iconColor = Colors.green;
        break;
      case 'var_analog':
        icon = Icons.show_chart;
        iconColor = Colors.lightBlue;
        break;
      case 'var_digital':
        icon = Icons.toggle_on;
        iconColor = Colors.orangeAccent;
        break;
      default:
        icon = Icons.insert_drive_file;
    }

    List<Map<String, dynamic>> children =
        (node['children'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
            [];

    if (children.isNotEmpty) {
      return ExpansionTile(
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(node['name'], style: const TextStyle(fontSize: 14)),
        childrenPadding: const EdgeInsets.only(left: 20),
        dense: true,
        onExpansionChanged: (expanded) {
          if (expanded) {
            // Encuentra el SystemObject correspondiente en _allObjects
            final SystemObject? obj =
                _allObjects.firstWhereOrNull((o) => o.id == node['id']);
            if (obj != null) {
              setState(() => _selectedObject = obj);
            }
          }
        },
        children: children.map((child) => _buildTreeNode(child)).toList(),
      );
    } else {
      return ListTile(
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(node['name'], style: const TextStyle(fontSize: 14)),
        dense: true,
        selected: _selectedObject?.id == node['id'],
        selectedTileColor: Colors.blue.withOpacity(0.1),
        onTap: () {
          // Encuentra el SystemObject real para manejar la edición
          final SystemObject? obj =
              _allObjects.firstWhereOrNull((o) => o.id == node['id']);
          if (obj != null) {
            setState(() => _selectedObject = obj);
          }
        },
      );
    }
  }

  List<Widget> _buildTreeNodes(int? parentId) {
    // Esta es la parte que debe manejar la reconstrucción del árbol.
    // Aquí se asume que _systemTree fue reemplazado por la lógica de reconstrucción real
    // (ya que no proporcionaste la función auxiliar de reconstrucción de árbol a partir de _allObjects)

    // Implementación placeholder (debes reemplazarla con tu lógica de jerarquía)
    final tempTree = [
      {
        'id': 1,
        'name': 'Server 1',
        'type': 'server',
        'children': [
          {
            'id': 2,
            'name': 'IO Bus',
            'type': 'folder',
            'children': [
              {
                'id': 3,
                'name': 'Modbus TCP',
                'type': 'device_modbus',
                'children': [
                  {
                    'id': 4,
                    'name': 'Temp.Value',
                    'type': 'var_analog',
                    'children': []
                  },
                ]
              },
            ]
          },
          {
            'id': 5,
            'name': 'Programs',
            'type': 'folder',
            'children': [
              {
                'id': 6,
                'name': 'HVAC Logic',
                'type': 'program',
                'children': []
              },
            ]
          },
          {
            'id': 7,
            'name': 'Graphics',
            'type': 'folder',
            'children': [
              // Simular un objeto de pantalla cargado
              {
                'id': 8,
                'name': 'Chiller Plant',
                'type': 'screen',
                'children': []
              },
            ]
          },
        ]
      },
    ];

    // Nota: Si usaste la estructura plana de la respuesta inicial,
    // la lógica de construcción de árbol debe estar implementada en otro lugar
    return tempTree.map((node) => _buildTreeNode(node)).toList();
  }

  Widget _buildRightPanel() {
    final activeObject = _selectedObject!;

    // 1. Lógica para cargar y decodificar propiedades
    String propertiesJson = activeObject.properties;
    Map<String, dynamic> props;
    try {
      props = jsonDecode(propertiesJson);
    } catch (_) {
      props = {}; // Fallback si el JSON es inválido
    }

    switch (activeObject.type) {
      case 'screen':
        // 2. Extraer la lista de widgets de la propiedad 'widgets' (si existe)
        // El tipo de dato debe coincidir exactamente con el que ScreenDesigner espera: List<Map<String, dynamic>>
        List<Map<String, dynamic>> initialWidgets = [];
        if (props.containsKey('widgets') && props['widgets'] is List) {
          initialWidgets =
              (props['widgets'] as List<dynamic>).cast<Map<String, dynamic>>();
        }

        return Column(
          children: [
            // Barra de herramientas del editor gráfico
            Container(
              height: 45,
              color: const Color(0xFFE0E0E0),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(Icons.monitor, color: Colors.teal),
                  const SizedBox(width: 10),
                  Text("Graphics Editor: ${activeObject.name}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // Botón para simular la adición de un widget
                  IconButton(
                    icon: const Icon(Icons.add_box, color: Colors.green),
                    onPressed: () => _addNewWidget(activeObject),
                    tooltip: 'Add New Widget (for Demo)',
                  ),
                ],
              ),
            ),
            // 3. Pasar los parámetros obligatorios
            Expanded(
              child: ScreenDesigner(
                widgets: initialWidgets,
                // Pasamos el callback que maneja la actualización del widget individual
                onWidgetChanged: _updateAndSaveScreenWidget,
                // Puedes añadir parámetros opcionales si los necesitas para la edición
                // canvasWidth: 1024,
                // canvasHeight: 768,
              ),
            ),
          ],
        );

      case 'program':
        String initialCode = props['code'] ?? 'REM Start your program here\n';
        // ... (Tu ScriptEditor, asumiendo que ya lo tienes implementado)
        return ScriptEditor(
          objectName: activeObject.name,
          initialCode: initialCode,
          onSave: (newCode) {
            final newProps = jsonEncode({"code": newCode});
            _saveObject(activeObject.id, activeObject.name, newProps);
          },
        );

      default:
        // Vista genérica de propiedades para otros objetos
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getIconForType(activeObject.type),
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 20),
              Text("Properties for: ${activeObject.name}",
                  style: const TextStyle(fontSize: 20)),
              Text("Type: ${activeObject.type}",
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.domain, color: Colors.white),
            SizedBox(width: 10),
            Text("DX Ascend - Workstation",
                style: TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: const Color(0xFF2C3E50),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: () {
              // En una aplicación real, guardarías el objeto activo.
              // En este diseño, el guardado se hace automáticamente con onWidgetChanged/onSave.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Auto-save is enabled (on change/move)")),
              );
            },
            tooltip: 'Manual Save (auto-save enabled)',
          ),
          IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchSystemTree),
        ],
      ),
      body: Row(
        children: [
          // --- PANEL IZQUIERDO: ÁRBOL DE SISTEMA ---
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xFFEFEFEF),
                  width: double.infinity,
                  child: const Text("System Tree",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black54)),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(children: _buildTreeNodes(null)),
                ),
              ],
            ),
          ),

          // --- PANEL DERECHO: ÁREA DE TRABAJO (EDITORES) ---
          Expanded(
            child: _selectedObject == null
                ? const Center(
                    child: Text("Select an object from the System Tree",
                        style: TextStyle(color: Colors.grey)))
                : _buildRightPanel(),
          ),
        ],
      ),
    );
  }
}

extension on List<SystemObject> {
  SystemObject? firstWhereOrNull(bool Function(SystemObject element) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
