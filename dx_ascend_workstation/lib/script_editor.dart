import 'package:flutter/material.dart';

enum ScriptDocumentType {
  program,
  function,
  eventProgram,
}

class ScriptEditor extends StatefulWidget {
  final String objectName;
  final String initialCode;
  final Function(String) onSave;

  const ScriptEditor({
    super.key,
    required this.objectName,
    required this.initialCode,
    required this.onSave,
  });

  @override
  State<ScriptEditor> createState() => _ScriptEditorState();
}

class _ScriptEditorState extends State<ScriptEditor>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _codeController;
  late final TabController _tabController;
  final List<TextEditingValue> _undoStack = [];
  final List<TextEditingValue> _redoStack = [];

  ScriptDocumentType _documentType = ScriptDocumentType.program;
  bool _showLineNumbers = true;
  bool _enableIntelliSense = true;
  bool _enableOutlining = true;
  bool _isProtected = false;
  bool _isChecking = false;
  bool _isSaving = false;
  bool _hasErrors = false;
  String _statusText = 'Listo para editar';
  bool _suspendHistory = false;
  final List<_ScriptDiagnostic> _diagnostics = [];
  final List<_ClipboardEntry> _clipboardHistory = [];
  final List<_ScriptVariable> _variables = [];
  final Map<String, String?> _bindings = {};

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode);
    _tabController = TabController(length: 4, vsync: this);
    _codeController.addListener(_onCodeChanged);
    _captureSnapshot();
    _parseVariables();
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    _captureSnapshot();
    _parseVariables();
  }

  void _captureSnapshot() {
    if (_suspendHistory) return;
    _undoStack.add(_codeController.value);
    if (_undoStack.length > 24) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    _suspendHistory = true;
    _redoStack.add(_codeController.value);
    _codeController.value = _undoStack.removeLast();
    _suspendHistory = false;
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _suspendHistory = true;
    _undoStack.add(_codeController.value);
    _codeController.value = _redoStack.removeLast();
    _suspendHistory = false;
  }

  void _parseVariables() {
    _variables
      ..clear()
      ..addAll(_ScriptVariableParser.parse(_codeController.text));
    for (final variable in _variables) {
      _bindings.putIfAbsent(variable.name, () => null);
    }
    setState(() {});
  }

  void _runCheck() {
    setState(() {
      _isChecking = true;
      _diagnostics.clear();
      _statusText = 'Ejecutando Check...';
    });

    final code = _codeController.text;
    final List<_ScriptDiagnostic> diags = [];

    if (code.trim().isEmpty) {
      diags.add(
        const _ScriptDiagnostic(
          severity: DiagnosticSeverity.error,
          message: 'El script está vacío',
          line: 1,
          column: 1,
        ),
      );
    }

    if (_documentType != ScriptDocumentType.function &&
        !RegExp(r'\bEnd\b', caseSensitive: false).hasMatch(code)) {
      diags.add(
        const _ScriptDiagnostic(
          severity: DiagnosticSeverity.error,
          message: 'Falta la sentencia "End"',
          line: 1,
          column: 1,
        ),
      );
    }

    final lines = code.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].runes.any((r) => r > 127)) {
        diags.add(
          _ScriptDiagnostic(
            severity: DiagnosticSeverity.warning,
            message: 'Caracteres no ASCII detectados',
            line: i + 1,
            column: 1,
          ),
        );
      }
      if (lines[i].length > 132) {
        diags.add(
          _ScriptDiagnostic(
            severity: DiagnosticSeverity.warning,
            message: 'Línea excede 132 caracteres (alerta visual)',
            line: i + 1,
            column: 132,
          ),
        );
      }
    }

    setState(() {
      _diagnostics.addAll(diags);
      _hasErrors = diags.any((d) => d.severity == DiagnosticSeverity.error);
      _statusText = _hasErrors
          ? 'Check con errores'
          : (diags.isEmpty ? 'Check OK' : 'Check con advertencias');
      _isChecking = false;
    });
  }

  Future<void> _handleSave() async {
    _runCheck();
    setState(() => _isSaving = true);

    await Future.delayed(const Duration(milliseconds: 300));
    widget.onSave(_codeController.text);

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _statusText = _hasErrors
          ? 'Guardado con errores (Run bloqueado)'
          : 'Guardado correctamente';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _hasErrors
              ? 'Script guardado pero no ejecutable hasta corregir errores'
              : 'Script guardado correctamente',
        ),
      ),
    );
  }

  void _toggleProtection() {
    setState(() {
      _isProtected = !_isProtected;
      _statusText = _isProtected ? 'Script protegido' : 'Script editable';
    });
  }

  void _copySelectionToClipboard() {
    final selection = _codeController.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final selected =
        _codeController.text.substring(selection.start, selection.end);
    setState(() {
      _clipboardHistory.insert(
        0,
        _ClipboardEntry(
          content: selected,
          pinned: false,
          timestamp: DateTime.now(),
        ),
      );
    });
  }

  void _insertClipboardEntry(String content) {
    final selection = _codeController.selection;
    final text = _codeController.text;
    final newText = text.replaceRange(
      selection.isValid ? selection.start : text.length,
      selection.isValid ? selection.end : text.length,
      content,
    );
    final cursor =
        (selection.isValid ? selection.start : text.length) + content.length;
    setState(() {
      _codeController.text = newText;
      _codeController.selection = TextSelection.collapsed(offset: cursor);
    });
    _parseVariables();
  }

  void _updateBinding(String variable, String? path) {
    setState(() {
      _bindings[variable] = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _buildToolbar(theme),
        _buildStatusBar(theme),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildEditorArea(theme)),
              const VerticalDivider(width: 1),
              SizedBox(width: 260, child: _buildBindingsPanel(theme)),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: 240, child: _buildBottomPanels(theme)),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    final canImportPE = _documentType != ScriptDocumentType.function;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _ToolbarGroup(
              label: 'Edición',
              children: [
                _ToolbarButton(
                  icon: Icons.add,
                  label: 'New',
                  onPressed: () => setState(() {
                    _codeController.clear();
                    _statusText = 'Nuevo documento';
                    _parseVariables();
                  }),
                ),
                _ToolbarButton(
                  icon: Icons.folder_open,
                  label: 'Open',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Abrir desde repositorio')),
                  ),
                ),
                _ToolbarButton(
                  icon: Icons.save,
                  label: 'Save',
                  onPressed: _isSaving ? null : _handleSave,
                ),
                _ToolbarButton(
                  icon: Icons.undo,
                  label: 'Undo',
                  onPressed: _undo,
                ),
                _ToolbarButton(
                  icon: Icons.redo,
                  label: 'Redo',
                  onPressed: _redo,
                ),
                _ToolbarButton(
                  icon: Icons.find_in_page,
                  label: 'Find',
                  onPressed: () => _focusQuickAction('Buscar en documento'),
                ),
                _ToolbarButton(
                  icon: Icons.find_replace,
                  label: 'Replace',
                  onPressed: () => _focusQuickAction('Reemplazar texto'),
                ),
                _ToolbarToggle(
                  icon: Icons.format_list_numbered,
                  label: 'Line #',
                  value: _showLineNumbers,
                  onChanged: (value) =>
                      setState(() => _showLineNumbers = value),
                ),
                _ToolbarToggle(
                  icon: Icons.lightbulb_outline,
                  label: 'IntelliSense',
                  value: _enableIntelliSense,
                  onChanged: (value) =>
                      setState(() => _enableIntelliSense = value),
                ),
                _ToolbarToggle(
                  icon: Icons.code,
                  label: 'Outlining',
                  value: _enableOutlining,
                  onChanged: (value) =>
                      setState(() => _enableOutlining = value),
                ),
              ],
            ),
            _ToolbarGroup(
              label: 'Check',
              children: [
                _ToolbarButton(
                  icon: Icons.bug_report_outlined,
                  label: 'Check',
                  onPressed: _isChecking ? null : _runCheck,
                ),
                _ToolbarButton(
                  icon: Icons.cleaning_services,
                  label: 'Clear',
                  onPressed: () => setState(() {
                    _diagnostics.clear();
                    _statusText = 'Errores limpiados';
                  }),
                ),
              ],
            ),
            _ToolbarGroup(
              label: 'Ejecución',
              children: [
                _ToolbarButton(
                  icon: Icons.refresh,
                  label: 'Run/Restart',
                  onPressed: _hasErrors
                      ? null
                      : () => _focusQuickAction('Run / Restart solicitado'),
                ),
                _ToolbarButton(
                  icon: Icons.stop_circle_outlined,
                  label: 'Stop',
                  onPressed: () => _focusQuickAction('Stop de ejecución'),
                ),
              ],
            ),
            _ToolbarGroup(
              label: 'Debug',
              children: [
                _ToolbarButton(
                  icon: Icons.bug_play,
                  label: 'Start',
                  onPressed: () =>
                      _focusQuickAction('Iniciar sesión de debugging'),
                ),
                _ToolbarButton(
                  icon: Icons.location_searching,
                  label: 'Trace',
                  onPressed: () => _focusQuickAction('Trace On'),
                ),
                _ToolbarButton(
                  icon: Icons.flag,
                  label: 'Breakpoint',
                  onPressed: () =>
                      _focusQuickAction('Toggle de breakpoint en línea'),
                ),
              ],
            ),
            _ToolbarGroup(
              label: 'Soporte',
              children: [
                _ToolbarButton(
                  icon: Icons.file_upload,
                  label: 'Import TXT',
                  onPressed: () => _insertClipboardEntry('// importado'),
                ),
                _ToolbarButton(
                  icon: Icons.file_open,
                  label: 'Import PE',
                  onPressed: canImportPE
                      ? () => _focusQuickAction('Import Plain English')
                      : null,
                ),
                _ToolbarButton(
                  icon: Icons.file_download,
                  label: 'Export',
                  onPressed: () =>
                      _focusQuickAction('Exportar a archivo de texto'),
                ),
                _ToolbarButton(
                  icon: Icons.settings,
                  label: 'Options',
                  onPressed: () => _openOptionsDialog(),
                ),
                _ToolbarToggle(
                  icon: Icons.lock_outline,
                  label: _isProtected ? 'Unprotect' : 'Protect',
                  value: _isProtected,
                  onChanged: (_) => _toggleProtection(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            _hasErrors ? Icons.error_outline : Icons.check_circle_outline,
            color: _hasErrors ? Colors.red : Colors.green,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusText,
              style: TextStyle(
                color: _hasErrors ? Colors.red : Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButton<ScriptDocumentType>(
            value: _documentType,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(
                value: ScriptDocumentType.program,
                child: Text('Program'),
              ),
              DropdownMenuItem(
                value: ScriptDocumentType.eventProgram,
                child: Text('Event Program'),
              ),
              DropdownMenuItem(
                value: ScriptDocumentType.function,
                child: Text('Function'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _documentType = value;
                _statusText = 'Tipo actualizado a ${value.name}';
              });
            },
          ),
          const SizedBox(width: 8),
          Text('IntelliSense: ${_enableIntelliSense ? 'On' : 'Off'}'),
          const SizedBox(width: 16),
          Text('Outlining: ${_enableOutlining ? 'On' : 'Off'}'),
        ],
      ),
    );
  }

  Widget _buildEditorArea(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                'Script: ${widget.objectName}',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              if (_isSaving)
                Row(
                  children: const [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 6),
                    Text('Guardando...'),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showLineNumbers)
                  Container(
                    width: 46,
                    color: Colors.grey.shade100,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 12),
                      itemCount: (_codeController.text.split('\n').length + 10)
                          .clamp(1, 9999),
                      itemBuilder: (ctx, i) => Text(
                        '${i + 1}'.padLeft(3, '0'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    onChanged: (_) => _parseVariables(),
                    readOnly: _isProtected,
                    maxLines: null,
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontFamily: 'Cascadia Code',
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBindingsPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          color: theme.colorScheme.surfaceVariant,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Bindings', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                'Vincula variables con rutas/valores del sistema.',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(10),
            itemCount: _variables.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final variable = _variables[index];
              final binding = _bindings[variable.name];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          variable.qualifier.toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: variable.isOutput
                            ? Colors.orange
                            : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          variable.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Ruta / PointId',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: binding ?? ''),
                    onChanged: (value) => _updateBinding(variable.name, value),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanels(ThemeData theme) {
    return DefaultTabController(
      length: _tabController.length,
      child: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.primaryColor,
              tabs: const [
                Tab(text: 'Variables'),
                Tab(text: 'Check / Errors'),
                Tab(text: 'Clipboard'),
                Tab(text: 'Code Library'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVariablesPanel(),
                _buildCheckPanel(),
                _buildClipboardPanel(),
                _buildCodeLibraryPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariablesPanel() {
    if (_variables.isEmpty) {
      return const Center(
        child: Text('Declara variables (Input/Output/Public) en el script'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _variables.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final variable = _variables[index];
        return ListTile(
          leading: Icon(
            variable.isOutput ? Icons.output : Icons.input,
            color: variable.isOutput ? Colors.orange : Colors.blue,
          ),
          title: Text(variable.name),
          subtitle: Text(
            'Tipo: ${variable.dataType}  ·  Qualifier: ${variable.qualifier}',
          ),
          trailing: SizedBox(
            width: 120,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Start Value',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => variable.startValue = value,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckPanel() {
    if (_diagnostics.isEmpty) {
      return const Center(
        child: Text('Sin errores. Ejecuta "Check" para validar el script.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _diagnostics.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final diag = _diagnostics[index];
        return ListTile(
          leading: Icon(
            diag.severity == DiagnosticSeverity.error
                ? Icons.error
                : Icons.warning,
            color:
                diag.severity == DiagnosticSeverity.error ? Colors.red : null,
          ),
          title: Text(diag.message),
          subtitle: Text('Línea ${diag.line}, Col ${diag.column}'),
        );
      },
    );
  }

  Widget _buildClipboardPanel() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _copySelectionToClipboard,
                icon: const Icon(Icons.copy),
                label: const Text('Copiar selección'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _clipboardHistory.clear();
                  });
                },
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Limpiar historial'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _clipboardHistory.isEmpty
                ? const Center(
                    child: Text('El historial está vacío (hasta 50 ítems).'),
                  )
                : ListView.separated(
                    itemCount: _clipboardHistory.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = _clipboardHistory[index];
                      return ListTile(
                        title: Text(
                          entry.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Guardado a las ${entry.timestamp.toLocal().toIso8601String()}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.keyboard_double_arrow_left),
                          tooltip: 'Insertar en el editor',
                          onPressed: () => _insertClipboardEntry(entry.content),
                        ),
                        leading: IconButton(
                          icon: Icon(
                            entry.pinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                          ),
                          onPressed: () => setState(() {
                            _clipboardHistory[index] =
                                entry.copyWith(pinned: !entry.pinned);
                          }),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeLibraryPanel() {
    final systemEntries = [
      'Sample: Numeric Input Loop',
      'Sample: Toggle Output',
      'Sample: Error Handler',
    ];

    final userEntries = [
      'Util: Clamp range',
      'Util: Fahrenheit to Celsius',
    ];

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: _CodeLibraryList(
              title: 'System Provided (read-only)',
              entries: systemEntries,
              onInsert: (entry) => _insertClipboardEntry('// $entry'),
              readOnly: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CodeLibraryList(
              title: 'Mis snippets',
              entries: userEntries,
              onInsert: (entry) => _insertClipboardEntry('// $entry'),
            ),
          ),
        ],
      ),
    );
  }

  void _focusQuickAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label)),
    );
  }

  void _openOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        double fontSize = 13;
        String fontFamily = 'Cascadia Code';
        return AlertDialog(
          title: const Text('Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Line numbers'),
                  const Spacer(),
                  Switch(
                    value: _showLineNumbers,
                    onChanged: (value) => setState(() {
                      _showLineNumbers = value;
                    }),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('IntelliSense'),
                  const Spacer(),
                  Switch(
                    value: _enableIntelliSense,
                    onChanged: (value) => setState(() {
                      _enableIntelliSense = value;
                    }),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Outlining'),
                  const Spacer(),
                  Switch(
                    value: _enableOutlining,
                    onChanged: (value) => setState(() {
                      _enableOutlining = value;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Font family'),
                    DropdownButton<String>(
                      value: fontFamily,
                      items: const [
                        DropdownMenuItem(
                          value: 'Cascadia Code',
                          child: Text('Cascadia Code'),
                        ),
                        DropdownMenuItem(
                          value: 'Consolas',
                          child: Text('Consolas'),
                        ),
                        DropdownMenuItem(
                          value: 'Courier New',
                          child: Text('Courier New'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          fontFamily = value;
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text('Font size'),
                    Slider(
                      min: 10,
                      max: 18,
                      divisions: 8,
                      value: fontSize,
                      onChanged: (value) {
                        setState(() {
                          fontSize = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
}

enum DiagnosticSeverity { error, warning }

class _ScriptDiagnostic {
  const _ScriptDiagnostic({
    required this.severity,
    required this.message,
    required this.line,
    required this.column,
  });

  final DiagnosticSeverity severity;
  final String message;
  final int line;
  final int column;
}

class _ClipboardEntry {
  const _ClipboardEntry({
    required this.content,
    required this.timestamp,
    required this.pinned,
  });

  final String content;
  final DateTime timestamp;
  final bool pinned;

  _ClipboardEntry copyWith({bool? pinned}) {
    return _ClipboardEntry(
      content: content,
      timestamp: timestamp,
      pinned: pinned ?? this.pinned,
    );
  }
}

class _ScriptVariable {
  _ScriptVariable({
    required this.name,
    required this.dataType,
    required this.qualifier,
    this.startValue,
  });

  final String name;
  final String dataType;
  final String qualifier;
  String? startValue;

  bool get isOutput => qualifier.toLowerCase() == 'output';
}

class _ScriptVariableParser {
  static final RegExp _variableMatcher = RegExp(
    r'^\s*(Numeric|String|Boolean)?\s*(Input|Output|Public|Local|Function|WebService|Arg)?\s+([A-Za-z_][A-Za-z0-9_]*)',
    caseSensitive: false,
    multiLine: true,
  );

  static List<_ScriptVariable> parse(String text) {
    final variables = <_ScriptVariable>[];
    final seen = <String>{};

    for (final match in _variableMatcher.allMatches(text)) {
      final type = match.group(1) ?? 'Numeric';
      final qualifier = match.group(2) ?? 'Local';
      final name = match.group(3) ?? '';
      final normalized = name.toLowerCase();
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      variables.add(
        _ScriptVariable(
          name: name,
          dataType: type,
          qualifier: qualifier,
        ),
      );
    }

    return variables;
  }
}

class _ToolbarGroup extends StatelessWidget {
  const _ToolbarGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
      ),
    );
  }
}

class _ToolbarToggle extends StatelessWidget {
  const _ToolbarToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FilterChip(
        avatar: Icon(icon, size: 14),
        selected: value,
        label: Text(label),
        onSelected: onChanged,
      ),
    );
  }
}

class _CodeLibraryList extends StatelessWidget {
  const _CodeLibraryList({
    required this.title,
    required this.entries,
    required this.onInsert,
    this.readOnly = false,
  });

  final String title;
  final List<String> entries;
  final bool readOnly;
  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text(entry),
                    trailing: IconButton(
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                      tooltip: 'Insertar en editor',
                      onPressed: () => onInsert(entry),
                    ),
                  );
                },
              ),
            ),
            if (!readOnly)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Agregar a biblioteca'),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo snippet'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Renombrar carpeta')),
                    ),
                    icon: const Icon(Icons.drive_file_rename_outline),
                    label: const Text('Renombrar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
