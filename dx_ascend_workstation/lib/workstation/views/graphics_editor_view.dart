import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../models/graphic_widget.dart';
import '../../models/screen.dart';
import '../../models/system_object.dart';
import '../api_config.dart';

class GraphicsEditorView extends StatefulWidget {
  final SystemObject systemObject;
  final List<SystemObject> availableValues;
  final ValueChanged<GraphicWidget?>? onWidgetSelected;
  final ValueChanged<Widget?>? onWidgetEditorChanged;
  const GraphicsEditorView(
      {super.key,
      required this.systemObject,
      required this.availableValues,
      this.onWidgetSelected,
      this.onWidgetEditorChanged});

  @override
  State<GraphicsEditorView> createState() => _GraphicsEditorViewState();
}

class _GraphicsEditorViewState extends State<GraphicsEditorView> {
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
          _loadingWidgets = false;
          _error = null;
        });
      widget.onWidgetSelected?.call(null);
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
    widget.onWidgetEditorChanged?.call(null);
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

        initial ??= await _fetchScreenByName(widget.systemObject.name);

      setState(() {
          _selectedScreen = initial;
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

  Future<void> _loadWidgets(int screenId,
      {bool allowMock = false, int? preferredId}) async {
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
      });
      final targetId = preferredId ?? _selectedWidget?.id;
      GraphicWidget? nextSelection;
      if (targetId != null) {
        for (final item in widgets) {
          if (item.id == targetId) {
            nextSelection = item;
            break;
          }
        }
      }
      _setSelectedWidget(
          nextSelection ?? (widgets.isEmpty ? null : widgets.first));
    } catch (e) {
      if (allowMock) {
        final mockWidgets = _buildMockWidgets(screenId);
        setState(() {
          _widgets = mockWidgets;
          _error = 'No se pudieron cargar los widgets: $e. '
              'Se muestran datos de ejemplo.';
        });
        final targetId = preferredId ?? _selectedWidget?.id;
        GraphicWidget? nextSelection;
        if (targetId != null) {
          for (final mock in mockWidgets) {
            if (mock.id == targetId) {
              nextSelection = mock;
              break;
            }
          }
        }
        nextSelection ??= mockWidgets.isEmpty ? null : mockWidgets.first;
        _setSelectedWidget(nextSelection, updateForm: false);
        if (nextSelection != null) {
          _fillForm(nextSelection);
        }
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
      await _loadWidgets(screen.id,
          allowMock: true, preferredId: widget.id);
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

  void _clearForm() {
    _nameCtrl.clear();
    _typeCtrl.clear();
    _xCtrl.clear();
    _yCtrl.clear();
    _widthCtrl.clear();
    _heightCtrl.clear();
    _configCtrl.clear();
  }

  void _notifyWidgetEditorChange() {
    if (widget.onWidgetEditorChanged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onWidgetEditorChanged!(_buildWidgetEditor());
    });
  }

  void _setSelectedWidget(GraphicWidget? widget, {bool updateForm = true}) {
    setState(() {
      _selectedWidget = widget;
      _selectedWidgetType = widget != null ? _matchWidgetType(widget.type) : null;
      _selectedBindingValue =
          widget != null ? _matchBindingFromConfig(widget.config) : null;
      if (widget == null) {
        _clearForm();
      }
    });

    if (widget != null && updateForm) {
      _fillForm(widget);
    }

    this.widget.onWidgetSelected?.call(widget);
    _notifyWidgetEditorChange();
  }

  void _updateWidgetPosition(GraphicWidget widget, Offset delta) {
    final newX = max(0, widget.x + delta.dx.round());
    final newY = max(0, widget.y + delta.dy.round());
    final updated = widget.copyWith(x: newX, y: newY);

    setState(() {
      final index = _widgets.indexWhere((element) => element.id == widget.id);
      if (index != -1) {
        _widgets[index] = updated;
      }
      if (_selectedWidget?.id == widget.id) {
        _selectedWidget = updated;
        _xCtrl.text = updated.x.toString();
        _yCtrl.text = updated.y.toString();
      }
    });

    _notifyWidgetEditorChange();
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
                                          Colors.green.withValues(alpha: 0.1),
                                    title: Text(widget.name),
                                    subtitle: Text(
                                        '${widget.type} • (${widget.x},${widget.y})'),
                                    onTap: () {
                                      _setSelectedWidget(widget);
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
                            color: Colors.grey.withValues(alpha: 0.3),
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
          _setSelectedWidget(widget);
        },
        onPanStart: (_) => _setSelectedWidget(widget),
        onPanUpdate: (details) {
          _updateWidgetPosition(widget, details.delta);
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
    final selectedWidget = _selectedWidget;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: selectedWidget == null
            ? const Center(
                child: Text('Selecciona un widget para ver y editar sus propiedades'),
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Propiedades del widget',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _field('Name', _nameCtrl, width: 200),
                        _typeDropdown(),
                        _field('X', _xCtrl,
                            width: 80, keyboard: TextInputType.number),
                        _field('Y', _yCtrl,
                            width: 80, keyboard: TextInputType.number),
                        _field('Width', _widthCtrl, width: 80,
                            keyboard: TextInputType.number),
                        _field('Height', _heightCtrl, width: 80,
                            keyboard: TextInputType.number),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _bindingDropdown(),
                    const SizedBox(height: 12),
                    const Text('Config JSON'),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 140,
                      child: TextField(
                        controller: _configCtrl,
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '{"label": "Temp", "value": "23°C"}',
                        ),
                        style:
                            const TextStyle(fontFamily: 'Courier New', fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _saveWidget,
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Guardar cambios'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _deleteWidget,
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Eliminar'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
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
        initialValue: value,
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
        initialValue: _selectedBindingValue,
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
