import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'screen_designer.dart';

const kEboGreen = Color(0xFF6CCB5F);
const kSlateSurface = Color(0xFF161B22);

BoxDecoration workstationPanelDecoration() {
  return BoxDecoration(
    color: const Color(0xFF1C232F),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white.withOpacity(0.05)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.35),
        blurRadius: 12,
        offset: const Offset(0, 10),
      ),
    ],
  );
}

void main() {
  runApp(const DxAscendWorkstationApp());
}

class DxAscendWorkstationApp extends StatelessWidget {
  const DxAscendWorkstationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DX-Ascend Workstation',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1218),
        colorScheme: ColorScheme.fromSeed(
          seedColor: kEboGreen,
          brightness: Brightness.dark,
        ).copyWith(
          background: const Color(0xFF0E1218),
          surface: kSlateSurface,
          primary: kEboGreen,
          secondary: kEboGreen,
        ),
        cardColor: kSlateSurface,
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1F2632),
          border: OutlineInputBorder(),
          labelStyle: TextStyle(color: Colors.white70),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B232E),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kEboGreen,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: const HomeTabsPage(),
    );
  }
}

class HomeTabsPage extends StatelessWidget {
  const HomeTabsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            _buildHeader(colorScheme),
            _buildToolbar(),
            Expanded(
              child: Row(
                children: [
                  _buildNavigationPane(),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kSlateSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.06)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 18,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2733),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                            ),
                            child: const TabBar(
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                              indicatorColor: kEboGreen,
                              tabs: [
                                Tab(text: 'Modbus'),
                                Tab(text: 'Pantallas'),
                                Tab(text: 'Bindings'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: TabBarView(
                                children: [
                                  ModbusTab(),
                                  ScreensTab(),
                                  BindingsTab(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildStatusBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1C5A3D), Color(0xFF163329)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: const [
                Icon(Icons.monitor, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'DX-Ascend Workstation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Row(
              children: [
                _chromeChip(Icons.layers, 'Workspace'),
                _chromeChip(Icons.rule_folder, 'Graphics'),
                _chromeChip(Icons.router, 'Modbus'),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.cloud_sync, color: colorScheme.onPrimary),
              const SizedBox(width: 6),
              Text(
                'Sync activo',
                style: TextStyle(color: colorScheme.onPrimary),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.person, color: Colors.white70, size: 18),
                    SizedBox(width: 8),
                    Text('Operador', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121821),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          _toolbarButton(Icons.save, 'Guardar'),
          const SizedBox(width: 6),
          _toolbarButton(Icons.refresh, 'Refrescar'),
          const SizedBox(width: 6),
          _toolbarButton(Icons.analytics, 'Tendencias'),
          const SizedBox(width: 6),
          _toolbarButton(Icons.settings, 'Preferencias'),
          const Spacer(),
          _toolbarButton(Icons.bug_report, 'Diagnóstico'),
          const SizedBox(width: 6),
          _toolbarButton(Icons.help_outline, 'Ayuda'),
        ],
      ),
    );
  }

  Widget _buildNavigationPane() {
    return Container(
      width: 240,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF11161E),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(4, 0)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Explorador',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text('Recorré sistemas y vistas', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Expanded(
            child: ListView(
              children: [
                _navTile(Icons.widgets, 'Gráficos y Widgets', 'Diseño y runtime'),
                _navTile(Icons.dns, 'Drivers Modbus', 'Interfaces y devices'),
                _navTile(Icons.link, 'Bindings', 'Relaciones datapoint'),
                _navTile(Icons.assessment, 'Alarmas', 'Eventos activos'),
                _navTile(Icons.settings_input_component, 'I/O', 'Puntos físicos'),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estado: conectado al servicio local',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121821),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: const [
          Icon(Icons.schedule, size: 18, color: Colors.white70),
          SizedBox(width: 8),
          Text('Último guardado hace 2 min', style: TextStyle(color: Colors.white70)),
          SizedBox(width: 24),
          Icon(Icons.security, size: 18, color: Colors.white70),
          SizedBox(width: 8),
          Text('Sesión segura', style: TextStyle(color: Colors.white70)),
          Spacer(),
          Icon(Icons.cloud_done, size: 18, color: Colors.white70),
          SizedBox(width: 8),
          Text('Servicio runtime online', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _chromeChip(IconData icon, String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(tooltip, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
      horizontalTitleGap: 8,
      dense: true,
      onTap: () {},
    );
  }
}

/* =========================
 *  TAB MODBUS
 * ========================= */

class ModbusTab extends StatefulWidget {
  const ModbusTab({super.key});

  @override
  State<ModbusTab> createState() => _ModbusTabState();
}

class _ModbusTabState extends State<ModbusTab> {
  final TextEditingController _serverUrlCtrl =
      TextEditingController(text: 'http://localhost:4000');

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _interfaces = [];

  final TextEditingController _ifNameCtrl = TextEditingController();
  final TextEditingController _ifIpCtrl = TextEditingController();
  final TextEditingController _ifPortCtrl = TextEditingController(text: '502');
  final TextEditingController _ifPollingCtrl =
      TextEditingController(text: '1000');
  bool _ifEnabled = true;

  List<Map<String, dynamic>> _devices = [];
  int? _selectedInterfaceIdForDevices;

  final TextEditingController _devNameCtrl = TextEditingController();
  final TextEditingController _devSlaveCtrl = TextEditingController();
  final TextEditingController _devTimeoutCtrl =
      TextEditingController(text: '1000');
  bool _devEnabled = true;

  List<Map<String, dynamic>> _datapoints = [];
  int? _selectedDeviceIdForPoints;

  final TextEditingController _dpNameCtrl = TextEditingController();
  String _dpFunction = 'holding_register';
  final TextEditingController _dpAddressCtrl = TextEditingController();
  final TextEditingController _dpQuantityCtrl =
      TextEditingController(text: '1');
  String _dpDatatype = 'int16';
  final TextEditingController _dpScaleCtrl = TextEditingController(text: '1.0');
  final TextEditingController _dpOffsetCtrl =
      TextEditingController(text: '0.0');
  final TextEditingController _dpUnitCtrl = TextEditingController();
  String _dpRw = 'R';
  final TextEditingController _dpPollingCtrl = TextEditingController();
  bool _dpEnabled = true;

  String get _baseUrl => _serverUrlCtrl.text.trim();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  void _setError(String? msg) {
    setState(() {
      _error = msg;
    });
  }

  Future<void> _loadInterfaces() async {
    if (_baseUrl.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri('/api/modbus/interfaces'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _interfaces = data.cast<Map<String, dynamic>>();
          if (_selectedInterfaceIdForDevices != null &&
              !_interfaces
                  .any((i) => i['id'] == _selectedInterfaceIdForDevices)) {
            _selectedInterfaceIdForDevices = null;
          }
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createInterface() async {
    if (_baseUrl.isEmpty) return;

    final name = _ifNameCtrl.text.trim();
    final ip = _ifIpCtrl.text.trim();
    final port = int.tryParse(_ifPortCtrl.text.trim());
    final polling = int.tryParse(_ifPollingCtrl.text.trim());

    if (name.isEmpty || ip.isEmpty) {
      _setError('Name e IP son obligatorios para la interface');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .post(
            _uri('/api/modbus/interfaces'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'ip_address': ip,
              if (port != null) 'port': port,
              if (polling != null) 'polling_ms': polling,
              'enabled': _ifEnabled,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 201) {
        _ifNameCtrl.clear();
        _ifIpCtrl.clear();
        _ifPortCtrl.text = '502';
        _ifPollingCtrl.text = '1000';
        _ifEnabled = true;
        await _loadInterfaces();
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDevices() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedInterfaceIdForDevices == null) {
      _setError('Seleccioná una interface para ver los devices');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri('/api/modbus/devices',
              {'interface_id': _selectedInterfaceIdForDevices.toString()}))
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _devices = data.cast<Map<String, dynamic>>();
          if (_selectedDeviceIdForPoints != null &&
              !_devices.any((d) => d['id'] == _selectedDeviceIdForPoints)) {
            _selectedDeviceIdForPoints = null;
          }
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createDevice() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedInterfaceIdForDevices == null) {
      _setError('Seleccioná una interface para crear un device');
      return;
    }

    final name = _devNameCtrl.text.trim();
    final slave = int.tryParse(_devSlaveCtrl.text.trim());
    final timeout = int.tryParse(_devTimeoutCtrl.text.trim());

    if (name.isEmpty || slave == null) {
      _setError('Name y Slave ID son obligatorios para el device');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .post(
            _uri('/api/modbus/devices'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'interface_id': _selectedInterfaceIdForDevices,
              'name': name,
              'slave_id': slave,
              if (timeout != null) 'timeout_ms': timeout,
              'enabled': _devEnabled,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 201) {
        _devNameCtrl.clear();
        _devSlaveCtrl.clear();
        _devTimeoutCtrl.text = '1000';
        _devEnabled = true;
        await _loadDevices();
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDatapoints() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedDeviceIdForPoints == null) {
      _setError('Seleccioná un device para ver los datapoints');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri('/api/modbus/datapoints',
              {'device_id': _selectedDeviceIdForPoints.toString()}))
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _datapoints = data.cast<Map<String, dynamic>>();
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createDatapoint() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedDeviceIdForPoints == null) {
      _setError('Seleccioná un device para crear datapoints');
      return;
    }

    final name = _dpNameCtrl.text.trim();
    final addr = int.tryParse(_dpAddressCtrl.text.trim());
    final qty = int.tryParse(_dpQuantityCtrl.text.trim());
    final scale = double.tryParse(_dpScaleCtrl.text.trim());
    final offset = double.tryParse(_dpOffsetCtrl.text.trim());
    final polling = _dpPollingCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(_dpPollingCtrl.text.trim());
    final unit =
        _dpUnitCtrl.text.trim().isEmpty ? null : _dpUnitCtrl.text.trim();

    if (name.isEmpty || addr == null) {
      _setError('Name y Address son obligatorios para el datapoint');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .post(
            _uri('/api/modbus/datapoints'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': _selectedDeviceIdForPoints,
              'name': name,
              'function': _dpFunction,
              'address': addr,
              if (qty != null) 'quantity': qty,
              'datatype': _dpDatatype,
              if (scale != null) 'scale': scale,
              if (offset != null) 'offset': offset,
              'unit': unit,
              'rw': _dpRw,
              'polling_ms': polling,
              'enabled': _dpEnabled,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 201) {
        _dpNameCtrl.clear();
        _dpAddressCtrl.clear();
        _dpQuantityCtrl.text = '1';
        _dpScaleCtrl.text = '1.0';
        _dpOffsetCtrl.text = '0.0';
        _dpUnitCtrl.clear();
        _dpRw = 'R';
        _dpPollingCtrl.clear();
        _dpEnabled = true;
        await _loadDatapoints();
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _ifNameCtrl.dispose();
    _ifIpCtrl.dispose();
    _ifPortCtrl.dispose();
    _ifPollingCtrl.dispose();
    _devNameCtrl.dispose();
    _devSlaveCtrl.dispose();
    _devTimeoutCtrl.dispose();
    _dpNameCtrl.dispose();
    _dpAddressCtrl.dispose();
    _dpQuantityCtrl.dispose();
    _dpScaleCtrl.dispose();
    _dpOffsetCtrl.dispose();
    _dpUnitCtrl.dispose();
    _dpPollingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serverUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL del servidor',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _loadInterfaces,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cargar Interfaces'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildInterfacesPanel(theme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildDevicesPanel(theme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildDatapointsPanel(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterfacesPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Interfaces Modbus', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: workstationPanelDecoration(),
            child: _interfaces.isEmpty
                ? const Center(child: Text('Sin interfaces'))
                : ListView.builder(
                    itemCount: _interfaces.length,
                    itemBuilder: (context, index) {
                      final itf = _interfaces[index];
                      final selected =
                          itf['id'] == _selectedInterfaceIdForDevices;
                      return ListTile(
                        selected: selected,
                        title: Text(
                            '${itf['name']} (${itf['ip_address']}:${itf['port']})'),
                        subtitle: Text(
                            'polling: ${itf['polling_ms']} ms | enabled: ${itf['enabled'] == 1 ? 'sí' : 'no'}'),
                        onTap: () {
                          setState(() {
                            _selectedInterfaceIdForDevices = itf['id'] as int;
                          });
                          _loadDevices();
                        },
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Nueva interface', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _ifNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _ifIpCtrl,
                decoration: const InputDecoration(
                  labelText: 'IP',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ifPortCtrl,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _ifPollingCtrl,
                decoration: const InputDecoration(
                  labelText: 'Polling ms',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 4),
            Column(
              children: [
                const Text('Enabled'),
                Switch(
                  value: _ifEnabled,
                  onChanged: (v) {
                    setState(() {
                      _ifEnabled = v;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _isLoading ? null : _createInterface,
              child: const Text('Agregar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDevicesPanel(ThemeData theme) {
    final interfacesOptions = _interfaces
        .map<DropdownMenuItem<int>>(
          (itf) => DropdownMenuItem<int>(
            value: itf['id'] as int,
            child: Text(itf['name'] as String),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Devices Modbus', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Interface',
                  border: OutlineInputBorder(),
                ),
                value: _selectedInterfaceIdForDevices,
                items: interfacesOptions,
                onChanged: (v) {
                  setState(() {
                    _selectedInterfaceIdForDevices = v;
                    _devices = [];
                    _selectedDeviceIdForPoints = null;
                    _datapoints = [];
                  });
                  if (v != null) {
                    _loadDevices();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _isLoading ? null : _loadDevices,
              child: const Text('Refrescar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: workstationPanelDecoration(),
            child: _devices.isEmpty
                ? const Center(child: Text('Sin devices'))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final dev = _devices[index];
                      final selected = dev['id'] == _selectedDeviceIdForPoints;
                      return ListTile(
                        selected: selected,
                        title:
                            Text('${dev['name']} (slave ${dev['slave_id']})'),
                        subtitle: Text(
                            'timeout: ${dev['timeout_ms']} ms | enabled: ${dev['enabled'] == 1 ? 'sí' : 'no'}'),
                        onTap: () {
                          setState(() {
                            _selectedDeviceIdForPoints = dev['id'] as int;
                          });
                          _loadDatapoints();
                        },
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Nuevo device', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _devNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _devSlaveCtrl,
                decoration: const InputDecoration(
                  labelText: 'Slave ID',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _devTimeoutCtrl,
                decoration: const InputDecoration(
                  labelText: 'Timeout ms',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 4),
            Column(
              children: [
                const Text('Enabled'),
                Switch(
                  value: _devEnabled,
                  onChanged: (v) {
                    setState(() {
                      _devEnabled = v;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _isLoading ? null : _createDevice,
              child: const Text('Agregar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDatapointsPanel(ThemeData theme) {
    final devicesOptions = _devices
        .map<DropdownMenuItem<int>>(
          (dev) => DropdownMenuItem<int>(
            value: dev['id'] as int,
            child: Text(dev['name'] as String),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Datapoints', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Device',
                  border: OutlineInputBorder(),
                ),
                value: _selectedDeviceIdForPoints,
                items: devicesOptions,
                onChanged: (v) {
                  setState(() {
                    _selectedDeviceIdForPoints = v;
                    _datapoints = [];
                  });
                  if (v != null) {
                    _loadDatapoints();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _isLoading ? null : _loadDatapoints,
              child: const Text('Refrescar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: workstationPanelDecoration(),
            child: _datapoints.isEmpty
                ? const Center(child: Text('Sin datapoints'))
                : ListView.builder(
                    itemCount: _datapoints.length,
                    itemBuilder: (context, index) {
                      final dp = _datapoints[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                            '${dp['name']} (${dp['function']} @ ${dp['address']})'),
                        subtitle: Text(
                            'type: ${dp['datatype']} | unit: ${dp['unit'] ?? '-'} | rw: ${dp['rw']} | enabled: ${dp['enabled'] == 1 ? 'sí' : 'no'}'),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Nuevo datapoint', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            SizedBox(
              width: 160,
              child: TextField(
                controller: _dpNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<String>(
                value: _dpFunction,
                decoration: const InputDecoration(
                  labelText: 'Function',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'coil',
                    child: Text('coil'),
                  ),
                  DropdownMenuItem(
                    value: 'discrete_input',
                    child: Text('discrete_input'),
                  ),
                  DropdownMenuItem(
                    value: 'holding_register',
                    child: Text('holding_register'),
                  ),
                  DropdownMenuItem(
                    value: 'input_register',
                    child: Text('input_register'),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _dpFunction = v ?? 'holding_register';
                  });
                },
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _dpAddressCtrl,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _dpQuantityCtrl,
                decoration: const InputDecoration(
                  labelText: 'Qty',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 120,
              child: DropdownButtonFormField<String>(
                value: _dpDatatype,
                decoration: const InputDecoration(
                  labelText: 'Datatype',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'int16',
                    child: Text('int16'),
                  ),
                  DropdownMenuItem(
                    value: 'uint16',
                    child: Text('uint16'),
                  ),
                  DropdownMenuItem(
                    value: 'int32',
                    child: Text('int32'),
                  ),
                  DropdownMenuItem(
                    value: 'float32',
                    child: Text('float32'),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _dpDatatype = v ?? 'int16';
                  });
                },
              ),
            ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _dpScaleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Scale',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _dpOffsetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Offset',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _dpUnitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 80,
              child: DropdownButtonFormField<String>(
                value: _dpRw,
                decoration: const InputDecoration(
                  labelText: 'R/W',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'R',
                    child: Text('R'),
                  ),
                  DropdownMenuItem(
                    value: 'W',
                    child: Text('W'),
                  ),
                  DropdownMenuItem(
                    value: 'RW',
                    child: Text('RW'),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _dpRw = v ?? 'R';
                  });
                },
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _dpPollingCtrl,
                decoration: const InputDecoration(
                  labelText: 'Poll ms (opt)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enabled'),
                Switch(
                  value: _dpEnabled,
                  onChanged: (v) {
                    setState(() {
                      _dpEnabled = v;
                    });
                  },
                ),
              ],
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _createDatapoint,
              child: const Text('Agregar'),
            ),
          ],
        ),
      ],
    );
  }
}

/* =========================
 *  TAB PANTALLAS
 * ========================= */

class ScreensTab extends StatefulWidget {
  const ScreensTab({super.key});

  @override
  State<ScreensTab> createState() => _ScreensTabState();
}

class _ScreensTabState extends State<ScreensTab> {
  final TextEditingController _serverUrlCtrl =
      TextEditingController(text: 'http://localhost:4000');

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _screens = [];
  int? _selectedScreenId;

  final TextEditingController _scrNameCtrl = TextEditingController();
  final TextEditingController _scrRouteCtrl = TextEditingController();
  final TextEditingController _scrDescCtrl = TextEditingController();
  bool _scrEnabled = true;

  List<Map<String, dynamic>> _widgets = [];

  final TextEditingController _wNameCtrl = TextEditingController();
  String _wType = 'text';
  final TextEditingController _wXCtrl = TextEditingController(text: '0');
  final TextEditingController _wYCtrl = TextEditingController(text: '0');
  final TextEditingController _wWidthCtrl = TextEditingController(text: '120');
  final TextEditingController _wHeightCtrl = TextEditingController(text: '80');

  String get _baseUrl => _serverUrlCtrl.text.trim();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  void _setError(String? msg) {
    setState(() {
      _error = msg;
    });
  }

  Future<void> _loadScreens() async {
    if (_baseUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri('/api/screens'))
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _screens = data.cast<Map<String, dynamic>>();
          if (_selectedScreenId != null &&
              !_screens.any((s) => s['id'] == _selectedScreenId)) {
            _selectedScreenId = null;
            _widgets = [];
          }
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createScreen() async {
    if (_baseUrl.isEmpty) return;

    final name = _scrNameCtrl.text.trim();
    final route = _scrRouteCtrl.text.trim();
    final desc = _scrDescCtrl.text.trim();

    if (name.isEmpty || route.isEmpty) {
      _setError('Name y Route son obligatorios para la pantalla');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .post(
            _uri('/api/screens'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'route': route,
              'description': desc.isEmpty ? null : desc,
              'enabled': _scrEnabled,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 201) {
        _scrNameCtrl.clear();
        _scrRouteCtrl.clear();
        _scrDescCtrl.clear();
        _scrEnabled = true;
        await _loadScreens();
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWidgets() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedScreenId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri('/api/screens/$_selectedScreenId/widgets'))
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _widgets = data.cast<Map<String, dynamic>>();
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createWidget() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedScreenId == null) {
      _setError('Seleccioná una pantalla para crear widgets');
      return;
    }

    final name = _wNameCtrl.text.trim();
    final x = int.tryParse(_wXCtrl.text.trim());
    final y = int.tryParse(_wYCtrl.text.trim());
    final w = int.tryParse(_wWidthCtrl.text.trim());
    final h = int.tryParse(_wHeightCtrl.text.trim());

    if (name.isEmpty) {
      _setError('Name es obligatorio para el widget');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .post(
            _uri('/api/screens/$_selectedScreenId/widgets'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'type': _wType,
              'name': name,
              if (x != null) 'x': x,
              if (y != null) 'y': y,
              if (w != null) 'width': w,
              if (h != null) 'height': h,
              'config_json': <String, dynamic>{},
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 201) {
        _wNameCtrl.clear();
        _wType = 'text';
        _wXCtrl.text = '0';
        _wYCtrl.text = '0';
        _wWidthCtrl.text = '120';
        _wHeightCtrl.text = '80';
        await _loadWidgets();
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _scrNameCtrl.dispose();
    _scrRouteCtrl.dispose();
    _scrDescCtrl.dispose();
    _wNameCtrl.dispose();
    _wXCtrl.dispose();
    _wYCtrl.dispose();
    _wWidthCtrl.dispose();
    _wHeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _onWidgetChanged(Map<String, dynamic> updated) async {
    if (_baseUrl.isEmpty) return;
    if (_selectedScreenId == null) return;

    final int id = (updated['id'] as num).toInt();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .put(
            _uri('/api/widgets/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'screen_id': _selectedScreenId,
              'name': updated['name'],
              'type': updated['type'],
              'x': updated['x'],
              'y': updated['y'],
              'width': updated['width'],
              'height': updated['height'],
              'config_json': updated['config_json'] ?? <String, dynamic>{},
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        await _loadWidgets();
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serverUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL del servidor',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _loadScreens,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cargar Pantallas'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildScreensPanel(theme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildWidgetsPanel(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreensPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pantallas', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: workstationPanelDecoration(),
            child: _screens.isEmpty
                ? const Center(child: Text('Sin pantallas'))
                : ListView.builder(
                    itemCount: _screens.length,
                    itemBuilder: (context, index) {
                      final scr = _screens[index];
                      final selected = scr['id'] == _selectedScreenId;
                      return ListTile(
                        selected: selected,
                        title: Text('${scr['name']} (${scr['route']})'),
                        subtitle: Text(
                            'enabled: ${scr['enabled'] == 1 ? 'sí' : 'no'}\n${scr['description'] ?? ''}'),
                        onTap: () {
                          setState(() {
                            _selectedScreenId = scr['id'] as int;
                          });
                          _loadWidgets();
                        },
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Nueva pantalla', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _scrNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _scrRouteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Route (ej. /sala-calderas)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _scrDescCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enabled'),
                Switch(
                  value: _scrEnabled,
                  onChanged: (v) {
                    setState(() {
                      _scrEnabled = v;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _isLoading ? null : _createScreen,
              child: const Text('Agregar'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWidgetsPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Widgets de la pantalla', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Expanded(
          child: Row(
            children: [
              // Lista de widgets (texto)
              Expanded(
                flex: 2,
                child: Container(
                  decoration: workstationPanelDecoration(),
                  child: _selectedScreenId == null
                      ? const Center(
                          child: Text('Seleccioná una pantalla'),
                        )
                      : _widgets.isEmpty
                          ? const Center(child: Text('Sin widgets'))
                          : ListView.builder(
                              itemCount: _widgets.length,
                              itemBuilder: (context, index) {
                                final w = _widgets[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                      '${w['name']} (${w['type']}) @ [${w['x']}, ${w['y']}]'),
                                  subtitle: Text(
                                      'size: ${w['width']} x ${w['height']}'),
                                );
                              },
                            ),
                ),
              ),
              const SizedBox(width: 8),
              // Canvas de edición visual
              Expanded(
                flex: 3,
                child: Container(
                  decoration: workstationPanelDecoration(),
                  padding: const EdgeInsets.all(8),
                  child: _selectedScreenId == null
                      ? const Center(
                          child: Text('Seleccioná una pantalla para editar'),
                        )
                      : ScreenDesigner(
                          widgets: _widgets,
                          onWidgetChanged: _onWidgetChanged,
                          canvasWidth: 800,
                          canvasHeight: 450,
                        ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Nuevo widget', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            SizedBox(
              width: 160,
              child: TextField(
                controller: _wNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 130,
              child: DropdownButtonFormField<String>(
                value: _wType,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'text', child: Text('text')),
                  DropdownMenuItem(value: 'bar', child: Text('bar')),
                  DropdownMenuItem(value: 'gauge', child: Text('gauge')),
                  DropdownMenuItem(
                      value: 'indicator', child: Text('indicator')),
                  DropdownMenuItem(value: 'fan', child: Text('fan')),
                  DropdownMenuItem(value: 'button', child: Text('button')),
                  DropdownMenuItem(value: 'custom', child: Text('custom')),
                ],
                onChanged: (v) {
                  setState(() {
                    _wType = v ?? 'text';
                  });
                },
              ),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _wXCtrl,
                decoration: const InputDecoration(
                  labelText: 'X',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _wYCtrl,
                decoration: const InputDecoration(
                  labelText: 'Y',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _wWidthCtrl,
                decoration: const InputDecoration(
                  labelText: 'Width',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _wHeightCtrl,
                decoration: const InputDecoration(
                  labelText: 'Height',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _createWidget,
              child: const Text('Agregar'),
            ),
          ],
        ),
      ],
    );
  }
}
/* =========================
 *  TAB BINDINGS
 * ========================= */

class BindingsTab extends StatefulWidget {
  const BindingsTab({super.key});

  @override
  State<BindingsTab> createState() => _BindingsTabState();
}

class _BindingsTabState extends State<BindingsTab> {
  final TextEditingController _serverUrlCtrl =
      TextEditingController(text: 'http://localhost:4000');

  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _screens = [];
  int? _selectedScreenId;

  List<Map<String, dynamic>> _widgets = [];
  int? _selectedWidgetId;

  List<Map<String, dynamic>> _devices = [];
  int? _selectedDeviceId;
  List<Map<String, dynamic>> _datapoints = [];
  int? _selectedDatapointId;

  List<Map<String, dynamic>> _bindings = [];

  String _mode = 'read';

  String get _baseUrl => _serverUrlCtrl.text.trim();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  void _setError(String? msg) {
    setState(() {
      _error = msg;
    });
  }

  Future<void> _loadScreens() async {
    if (_baseUrl.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri('/api/screens'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _screens = data.cast<Map<String, dynamic>>();
          if (_selectedScreenId != null &&
              !_screens.any((s) => s['id'] == _selectedScreenId)) {
            _selectedScreenId = null;
            _widgets = [];
            _bindings = [];
          }
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWidgets() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedScreenId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri('/api/screens/$_selectedScreenId/widgets'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _widgets = data.cast<Map<String, dynamic>>();
          if (_selectedWidgetId != null &&
              !_widgets.any((w) => w['id'] == _selectedWidgetId)) {
            _selectedWidgetId = null;
          }
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDevices() async {
    if (_baseUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri('/api/modbus/devices'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _devices = data.cast<Map<String, dynamic>>();
          if (_selectedDeviceId != null &&
              !_devices.any((d) => d['id'] == _selectedDeviceId)) {
            _selectedDeviceId = null;
            _datapoints = [];
          }
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDatapoints() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedDeviceId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri('/api/modbus/datapoints',
              {'device_id': _selectedDeviceId.toString()}))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _datapoints = data.cast<Map<String, dynamic>>();
          if (_selectedDatapointId != null &&
              !_datapoints.any((dp) => dp['id'] == _selectedDatapointId)) {
            _selectedDatapointId = null;
          }
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBindings() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedScreenId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .get(_uri(
              '/api/bindings', {'screen_id': _selectedScreenId.toString()}))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _bindings = data.cast<Map<String, dynamic>>();
        });
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createBinding() async {
    if (_baseUrl.isEmpty) return;
    if (_selectedScreenId == null) {
      _setError('Seleccioná una pantalla');
      return;
    }
    if (_selectedWidgetId == null) {
      _setError('Seleccioná un widget');
      return;
    }
    if (_selectedDatapointId == null) {
      _setError('Seleccioná un datapoint');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .post(
            _uri('/api/bindings'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'widget_id': _selectedWidgetId,
              'datapoint_id': _selectedDatapointId,
              'mode': _mode,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 201) {
        await _loadBindings();
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBinding(int id) async {
    if (_baseUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final resp = await http
          .delete(_uri('/api/bindings/$id'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 204) {
        _bindings.removeWhere((b) => b['id'] == id);
        setState(() {});
      } else {
        _setError('Error HTTP ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serverUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL del servidor',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _loadScreens,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cargar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildScreensWidgetsPanel(theme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _buildDevicesDatapointsPanel(theme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _buildBindingsPanel(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreensWidgetsPanel(ThemeData theme) {
    final screensOptions = _screens
        .map<DropdownMenuItem<int>>(
          (s) => DropdownMenuItem<int>(
            value: s['id'] as int,
            child: Text(s['name'] as String),
          ),
        )
        .toList();

    final widgetsOptions = _widgets
        .map<DropdownMenuItem<int>>(
          (w) => DropdownMenuItem<int>(
            value: w['id'] as int,
            child: Text('${w['name']} (${w['type']})'),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pantallas / Widgets', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(
            labelText: 'Pantalla',
            border: OutlineInputBorder(),
          ),
          value: _selectedScreenId,
          items: screensOptions,
          onChanged: (v) {
            setState(() {
              _selectedScreenId = v;
              _widgets = [];
              _selectedWidgetId = null;
              _bindings = [];
            });
            if (v != null) {
              _loadWidgets();
              _loadBindings();
            }
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(
            labelText: 'Widget',
            border: OutlineInputBorder(),
          ),
          value: _selectedWidgetId,
          items: widgetsOptions,
          onChanged: (v) {
            setState(() {
              _selectedWidgetId = v;
            });
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: workstationPanelDecoration(),
            child: _widgets.isEmpty
                ? const Center(child: Text('Sin widgets cargados'))
                : ListView.builder(
                    itemCount: _widgets.length,
                    itemBuilder: (context, index) {
                      final w = _widgets[index];
                      return ListTile(
                        dense: true,
                        title: Text('${w['name']} (${w['type']})'),
                        subtitle: Text(
                            'pos: [${w['x']}, ${w['y']}] size: ${w['width']}x${w['height']}'),
                        onTap: () {
                          setState(() {
                            _selectedWidgetId = w['id'] as int;
                          });
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesDatapointsPanel(ThemeData theme) {
    final devicesOptions = _devices
        .map<DropdownMenuItem<int>>(
          (d) => DropdownMenuItem<int>(
            value: d['id'] as int,
            child: Text('${d['name']} (slave ${d['slave_id']})'),
          ),
        )
        .toList();

    final datapointsOptions = _datapoints
        .map<DropdownMenuItem<int>>(
          (dp) => DropdownMenuItem<int>(
            value: dp['id'] as int,
            child: Text('${dp['name']} @ ${dp['address']}'),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Devices / Datapoints', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Device',
                  border: OutlineInputBorder(),
                ),
                value: _selectedDeviceId,
                items: devicesOptions,
                onChanged: (v) {
                  setState(() {
                    _selectedDeviceId = v;
                    _datapoints = [];
                    _selectedDatapointId = null;
                  });
                  if (v != null) {
                    _loadDatapoints();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            ElevatedButton(
              onPressed: _isLoading ? null : _loadDevices,
              child: const Text('Refrescar Devices'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(
            labelText: 'Datapoint',
            border: OutlineInputBorder(),
          ),
          value: _selectedDatapointId,
          items: datapointsOptions,
          onChanged: (v) {
            setState(() {
              _selectedDatapointId = v;
            });
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: workstationPanelDecoration(),
            child: _datapoints.isEmpty
                ? const Center(child: Text('Sin datapoints cargados'))
                : ListView.builder(
                    itemCount: _datapoints.length,
                    itemBuilder: (context, index) {
                      final dp = _datapoints[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                            '${dp['name']} (${dp['function']} @ ${dp['address']})'),
                        subtitle: Text(
                            'type: ${dp['datatype']} | unit: ${dp['unit'] ?? '-'} | rw: ${dp['rw']}'),
                        onTap: () {
                          setState(() {
                            _selectedDatapointId = dp['id'] as int;
                          });
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildBindingsPanel(ThemeData theme) {
    final modeOptions = const [
      DropdownMenuItem(value: 'read', child: Text('read')),
      DropdownMenuItem(value: 'write', child: Text('write')),
      DropdownMenuItem(value: 'readwrite', child: Text('readwrite')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bindings', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: workstationPanelDecoration(),
            child: _selectedScreenId == null
                ? const Center(child: Text('Seleccioná una pantalla'))
                : _bindings.isEmpty
                    ? const Center(child: Text('Sin bindings'))
                    : ListView.builder(
                        itemCount: _bindings.length,
                        itemBuilder: (context, index) {
                          final b = _bindings[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                                'Widget: ${b['widget_name']} ↔ ${b['datapoint_name']}'),
                            subtitle: Text(
                                'screen: ${b['screen_name']} | mode: ${b['mode']} | ${b['datapoint_function']} @ ${b['datapoint_address']} ${b['datapoint_unit'] ?? ''}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: _isLoading
                                  ? null
                                  : () => _deleteBinding(b['id'] as int),
                            ),
                          );
                        },
                      ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Nuevo binding', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Mode',
                  border: OutlineInputBorder(),
                ),
                value: _mode,
                items: modeOptions,
                onChanged: (v) {
                  setState(() {
                    _mode = v ?? 'read';
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _createBinding,
              child: const Text('Agregar'),
            ),
          ],
        ),
      ],
    );
  }
}
