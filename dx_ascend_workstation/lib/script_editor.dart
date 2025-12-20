import 'package:flutter/material.dart';

enum ScriptDocumentType {
  program,
  function,
  eventProgram,
}

enum ScriptRuntimeState { running, stopped, error }

enum DiagnosticSeverity { error, warning, info }

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
  static const int _historyLimit = 24;
  static const int _maxClipboardEntries = 50;

  late final TextEditingController _codeController;
  late final ScrollController _editorScrollController;
  late final TabController _tabController;

  final List<TextEditingValue> _undoStack = [];
  final List<TextEditingValue> _redoStack = [];
  final List<_ScriptDiagnostic> _diagnostics = [];
  final List<_ClipboardEntry> _clipboardHistory = [];
  final List<_ScriptVariable> _variables = [];
  final Map<String, _ScriptBinding> _bindings = {};
  final Set<int> _breakpoints = <int>{};

  late _ScriptDocument _document;
  _EditorSettings _settings = _EditorSettings.defaults();

  bool _suspendHistory = false;
  bool _isChecking = false;
  bool _isSaving = false;
  bool _isDebugging = false;
  bool _traceOn = false;
  bool _overwriteMode = false;
  String _statusText = 'Listo para editar';
  ScriptRuntimeState _runtimeState = ScriptRuntimeState.stopped;
  DateTime? _lastStartAt;
  String? _protectionPassword;

  final _CodeLibrary _codeLibrary = _CodeLibrary(
    systemFolders: const [
      _CodeLibraryFolder(
        name: 'System Provided',
        isReadOnly: true,
        entries: [
          _CodeLibraryEntry(name: 'Numeric Input Loop'),
          _CodeLibraryEntry(name: 'Toggle Output'),
          _CodeLibraryEntry(name: 'Error Handler'),
        ],
      ),
    ],
    folders: [
      _CodeLibraryFolder(
        name: 'Mis snippets',
        entries: const [
          _CodeLibraryEntry(name: 'Clamp range'),
          _CodeLibraryEntry(name: 'Fahrenheit to Celsius'),
        ],
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _document = _ScriptDocument(
      id: widget.objectName,
      name: widget.objectName,
      type: ScriptDocumentType.program,
      content: widget.initialCode,
      isDirty: false,
      isProtected: false,
      lastSavedAt: null,
      capabilities: const _ScriptCapabilities(
        canRun: true,
        canDebug: true,
        canProtect: true,
        canImportPE: true,
        canConvertPE: true,
      ),
    );

    _codeController = TextEditingController(text: widget.initialCode);
    _editorScrollController = ScrollController();
    _tabController = TabController(length: 4, vsync: this);

    _codeController.addListener(_onCodeChanged);
    _captureSnapshot();
    _parseVariables();
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _editorScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_document.isProtected) return;
    _captureSnapshot();
    _document = _document.copyWith(
      content: _codeController.text,
      isDirty: true,
    );
    _parseVariables();
    _updateCursorStatus();
  }

  void _captureSnapshot() {
    if (_suspendHistory) return;
    _undoStack.add(_codeController.value);
    if (_undoStack.length > _historyLimit) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty || _document.isProtected) return;
    _suspendHistory = true;
    _redoStack.add(_codeController.value);
    _codeController.value = _undoStack.removeLast();
    _suspendHistory = false;
  }

  void _redo() {
    if (_redoStack.isEmpty || _document.isProtected) return;
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
      _bindings.putIfAbsent(
        variable.name,
        () => _ScriptBinding(variableName: variable.name),
      );
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

    if (_document.type != ScriptDocumentType.function &&
        !RegExp(r'\\bEnd\\b', caseSensitive: false).hasMatch(code)) {
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
      _statusText = diags.any((d) => d.severity == DiagnosticSeverity.error)
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
      _document = _document.copyWith(
        isDirty: false,
        lastSavedAt: DateTime.now(),
      );
      _isSaving = false;
      _statusText = _diagnostics.any(
        (d) => d.severity == DiagnosticSeverity.error,
      )
          ? 'Guardado con errores (Run bloqueado)'
          : 'Guardado correctamente';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _diagnostics.any((d) => d.severity == DiagnosticSeverity.error)
              ? 'Script guardado pero no ejecutable hasta corregir errores'
              : 'Script guardado correctamente',
        ),
      ),
    );
  }

  void _toggleProtection() async {
    if (!_document.isProtected) {
      final password = await _requestPassword('Protect');
      if (password == null) return;
      setState(() {
        _protectionPassword = password;
        _document = _document.copyWith(isProtected: true);
        _statusText = 'Script protegido';
      });
    } else {
      final password = await _requestPassword('Unprotect');
      if (password == _protectionPassword) {
        setState(() {
          _document = _document.copyWith(isProtected: false);
          _statusText = 'Script editable';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password incorrecto para unprotect')),
        );
      }
    }
  }

  Future<String?> _requestPassword(String action) async {
    String value = '';
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$action code'),
        content: TextField(
          autofocus: true,
          obscureText: true,
          maxLength: 25,
          decoration: const InputDecoration(
            labelText: 'Password (4-25 caracteres)',
          ),
          onChanged: (text) => value = text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: value.length < 4
                ? null
                : () => Navigator.of(context).pop(value),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
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
      _trimClipboard();
    });
  }

  void _trimClipboard() {
    while (_clipboardHistory.length > _maxClipboardEntries) {
      final lastPinnedIndex =
          _clipboardHistory.lastIndexWhere((entry) => entry.pinned);
      if (lastPinnedIndex == _clipboardHistory.length - 1) break;
      _clipboardHistory.removeLast();
    }
  }

  void _insertClipboardEntry(String content) {
    final selection = _codeController.selection;
    final text = _codeController.text;
    final insertAt = selection.isValid ? selection.start : text.length;
    final newText = text.replaceRange(
      selection.isValid ? selection.start : text.length,
      selection.isValid ? selection.end : text.length,
      content,
    );
    final cursor = insertAt + content.length;
    setState(() {
      _codeController.text = newText;
      _codeController.selection = TextSelection.collapsed(offset: cursor);
    });
    _parseVariables();
  }

  void _updateBinding(String variable, String? path, String direction) {
    setState(() {
      _bindings[variable] = _bindings[variable]!
          .copyWith(targetPath: path, direction: direction);
    });
  }

  void _toggleBreakpointAtCursor() {
    final line = _currentLine;
    if (line == null) return;
    setState(() {
      if (_breakpoints.contains(line)) {
        _breakpoints.remove(line);
      } else {
        _breakpoints.add(line);
      }
    });
  }

  int? get _currentLine {
    final selection = _codeController.selection;
    if (!selection.isValid) return null;
    final textUntilCursor = _codeController.text.substring(0, selection.start);
    return textUntilCursor.split('\n').length;
  }

  void _navigateToLine(int line, int column) {
    final lines = _codeController.text.split('\n');
    int offset = 0;
    for (int i = 0; i < line - 1 && i < lines.length; i++) {
      offset += lines[i].length + 1;
    }
    offset += column - 1;
    offset = offset.clamp(0, _codeController.text.length);
    _codeController.selection = TextSelection.collapsed(offset: offset);
    _updateCursorStatus();
  }

  void _updateCursorStatus() {
    final line = _currentLine ?? 1;
    final selection = _codeController.selection;
    int column = 1;
    if (selection.isValid) {
      final textUntilCursor =
          _codeController.text.substring(0, selection.start).split('\n');
      column = textUntilCursor.isEmpty
          ? 1
          : textUntilCursor.last.length + 1;
    }
    setState(() {
      _statusText =
          'Línea $line, Col $column · ${_overwriteMode ? 'OVR' : 'INS'}';
    });
  }

  void _performFindReplace({required bool replace}) {
    final findController = TextEditingController();
    final replaceController = TextEditingController();
    bool matchCase = false;
    bool wholeWord = false;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(replace ? 'Find / Replace' : 'Find'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: findController,
                decoration: const InputDecoration(labelText: 'Find'),
              ),
              if (replace)
                TextField(
                  controller: replaceController,
                  decoration: const InputDecoration(labelText: 'Replace with'),
                ),
              CheckboxListTile(
                value: matchCase,
                onChanged: (value) => setState(() => matchCase = value ?? false),
                title: const Text('Match case'),
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: wholeWord,
                onChanged: (value) => setState(() => wholeWord = value ?? false),
                title: const Text('Whole word'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            TextButton(
              onPressed: () {
                _runFindAndReplace(
                  query: findController.text,
                  replacement: replaceController.text,
                  matchCase: matchCase,
                  wholeWord: wholeWord,
                  replaceAll: replace,
                );
                Navigator.of(context).pop();
              },
              child: Text(replace ? 'Replace all' : 'Find next'),
            ),
          ],
        );
      },
    );
  }

  void _runFindAndReplace({
    required String query,
    required String replacement,
    required bool matchCase,
    required bool wholeWord,
    required bool replaceAll,
  }) {
    if (query.isEmpty) return;
    final text = _codeController.text;
    final pattern = wholeWord ? '\\b$query\\b' : query;
    final regExp = RegExp(pattern, caseSensitive: matchCase);

    if (replaceAll) {
      final newText = text.replaceAll(regExp, replacement);
      _codeController.text = newText;
      _document = _document.copyWith(content: newText, isDirty: true);
      return;
    }

    final selection = _codeController.selection;
    final startIndex = selection.isValid ? selection.end : 0;
    final match = regExp.firstMatch(text.substring(startIndex)) ??
        regExp.firstMatch(text);
    if (match != null) {
      final matchStart = match.start + (match == regExp.firstMatch(text)
          ? 0
          : startIndex);
      final matchEnd = matchStart + match.group(0)!.length;
      _codeController.selection =
          TextSelection(baseOffset: matchStart, extentOffset: matchEnd);
      if (replaceAll == false && replacement.isNotEmpty) {
        _codeController.text = text.replaceRange(matchStart, matchEnd, replacement);
      }
    }
  }

  void _toggleComment() {
    final selection = _codeController.selection;
    if (!selection.isValid) return;
    final text = _codeController.text;
    final lines = text.split('\n');
    int startLine =
        text.substring(0, selection.start).split('\n').length - 1;
    int endLine = text.substring(0, selection.end).split('\n').length - 1;

    for (int i = startLine; i <= endLine && i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('//')) {
        lines[i] = lines[i].replaceFirst('//', '');
      } else {
        lines[i] = '//${lines[i]}';
      }
    }

    final newText = lines.join('\n');
    setState(() {
      _codeController.text = newText;
      _document = _document.copyWith(content: newText, isDirty: true);
    });
  }

  void _importText() {
    _insertClipboardEntry('// Texto importado en ${DateTime.now()}\n');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Import desde ${_settings.importPath}')),
    );
  }

  void _importPlainEnglish() {
    if (_document.type == ScriptDocumentType.function) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Import PE no permitido en Script Function'),
        ),
      );
      return;
    }
    _insertClipboardEntry('// Plain English convertido\n');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import Plain English ejecutado')),
    );
  }

  void _exportText() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exportado a ${_settings.exportPath}/script.txt')),
    );
  }

  void _convertPlainEnglish() {
    if (!_document.capabilities.canConvertPE) return;
    if (_document.type == ScriptDocumentType.function) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Convertir PE no disponible en funciones'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conversión Plain English solicitada')),
    );
  }

  void _startDebugging() {
    if (!_document.capabilities.canDebug) return;
    setState(() {
      _isDebugging = true;
      _runtimeState = ScriptRuntimeState.running;
      _lastStartAt = DateTime.now();
      _statusText = 'Debugging activo';
    });
  }

  void _stopDebugging() {
    setState(() {
      _isDebugging = false;
      _runtimeState = ScriptRuntimeState.stopped;
      _statusText = 'Debugging detenido';
    });
  }

  void _setNextStatement() {
    final line = _currentLine;
    if (line == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mover ejecución a línea $line')),
    );
  }

  void _restartProgram() {
    if (_diagnostics.any((d) => d.severity == DiagnosticSeverity.error)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Corregir errores antes de ejecutar')),
      );
      return;
    }
    setState(() {
      _runtimeState = ScriptRuntimeState.running;
      _lastStartAt = DateTime.now();
      _statusText = 'Run/Restart solicitado';
    });
  }

  void _stopProgram() {
    setState(() {
      _runtimeState = ScriptRuntimeState.stopped;
      _statusText = 'Ejecución detenida';
    });
  }

  void _openOptionsDialog() {
    _EditorSettings temp = _settings;
    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 3,
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              return AlertDialog(
                title: const Text('Options'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'General'),
                          Tab(text: 'Fonts & Colors'),
                          Tab(text: 'Paths'),
                        ],
                      ),
                      SizedBox(
                        height: 260,
                        child: TabBarView(
                          children: [
                            _OptionsGeneralTab(
                              settings: temp,
                              onChanged: (value) => setLocalState(() => temp = value),
                            ),
                            _OptionsFontsTab(
                              settings: temp,
                              onChanged: (value) => setLocalState(() => temp = value),
                            ),
                            _OptionsPathsTab(
                              settings: temp,
                              onChanged: (value) => setLocalState(() => temp = value),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => setLocalState(() => temp = _EditorSettings.defaults()),
                    child: const Text('Restore default'),
                  ),
                  FilledButton(
                    onPressed: () {
                      setState(() => _settings = temp);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
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
              SizedBox(width: 280, child: _buildBindingsPanel(theme)),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(height: 260, child: _buildBottomPanels(theme)),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    final canImportPE =
        _document.type != ScriptDocumentType.function && _document.capabilities.canImportPE;

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
                    _document = _document.copyWith(isDirty: true, content: '');
                    _statusText = 'Nuevo documento';
                    _parseVariables();
                  }),
                ),
                _ToolbarButton(
                  icon: Icons.folder_open,
                  label: 'Open',
                  onPressed: () => _focusQuickAction('Abrir desde repositorio'),
                ),
                _ToolbarButton(
                  icon: Icons.save,
                  label: 'Save',
                  onPressed: _isSaving ? null : _handleSave,
                ),
                _ToolbarButton(icon: Icons.undo, label: 'Undo', onPressed: _undo),
                _ToolbarButton(icon: Icons.redo, label: 'Redo', onPressed: _redo),
                _ToolbarButton(
                  icon: Icons.find_in_page,
                  label: 'Find',
                  onPressed: () => _performFindReplace(replace: false),
                ),
                _ToolbarButton(
                  icon: Icons.find_replace,
                  label: 'Replace',
                  onPressed: () => _performFindReplace(replace: true),
                ),
                _ToolbarToggle(
                  icon: Icons.format_list_numbered,
                  label: 'Line #',
                  value: _settings.showLineNumbers,
                  onChanged: (value) => setState(() => _settings =
                      _settings.copyWith(showLineNumbers: value ?? _settings.showLineNumbers)),
                ),
                _ToolbarToggle(
                  icon: Icons.lightbulb_outline,
                  label: 'IntelliSense',
                  value: _settings.enableIntelliSense,
                  onChanged: (value) => setState(() => _settings =
                      _settings.copyWith(enableIntelliSense: value ?? _settings.enableIntelliSense)),
                ),
                _ToolbarToggle(
                  icon: Icons.code,
                  label: 'Outlining',
                  value: _settings.enableOutlining,
                  onChanged: (value) => setState(() => _settings =
                      _settings.copyWith(enableOutlining: value ?? _settings.enableOutlining)),
                ),
                _ToolbarButton(
                  icon: Icons.comment,
                  label: 'Comment',
                  onPressed: _toggleComment,
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
                  onPressed: _diagnostics.any((d) => d.severity == DiagnosticSeverity.error)
                      ? null
                      : _restartProgram,
                ),
                _ToolbarButton(
                  icon: Icons.stop_circle_outlined,
                  label: 'Stop',
                  onPressed: _stopProgram,
                ),
              ],
            ),
            _ToolbarGroup(
              label: 'Debug',
              children: [
                _ToolbarButton(
                  icon: Icons.bug_report,
                  label: 'Start',
                  onPressed: _document.capabilities.canDebug ? _startDebugging : null,
                ),
                _ToolbarButton(
                  icon: Icons.stop,
                  label: 'Stop',
                  onPressed: _isDebugging ? _stopDebugging : null,
                ),
                _ToolbarToggle(
                  icon: Icons.location_searching,
                  label: 'Trace',
                  value: _traceOn,
                  onChanged: (value) => setState(() => _traceOn = value ?? false),
                ),
                _ToolbarButton(
                  icon: Icons.flag,
                  label: 'Breakpoint',
                  onPressed: _toggleBreakpointAtCursor,
                ),
                _ToolbarButton(
                  icon: Icons.fast_forward,
                  label: 'Step',
                  onPressed: () => _focusQuickAction('Step ejecutado'),
                ),
                _ToolbarButton(
                  icon: Icons.play_arrow,
                  label: 'Go (F5)',
                  onPressed: () => _focusQuickAction('Go solicitado'),
                ),
                _ToolbarButton(
                  icon: Icons.double_arrow,
                  label: 'Next stmt',
                  onPressed: _setNextStatement,
                ),
              ],
            ),
            _ToolbarGroup(
              label: 'Soporte',
              children: [
                _ToolbarButton(
                  icon: Icons.file_upload,
                  label: 'Import TXT',
                  onPressed: _importText,
                ),
                _ToolbarButton(
                  icon: Icons.file_open,
                  label: 'Import PE',
                  onPressed: canImportPE ? _importPlainEnglish : null,
                ),
                _ToolbarButton(
                  icon: Icons.swap_horiz,
                  label: 'Convert PE',
                  onPressed: _document.capabilities.canConvertPE
                      ? _convertPlainEnglish
                      : null,
                ),
                _ToolbarButton(
                  icon: Icons.file_download,
                  label: 'Export',
                  onPressed: _exportText,
                ),
                _ToolbarButton(
                  icon: Icons.settings,
                  label: 'Options',
                  onPressed: _openOptionsDialog,
                ),
                _ToolbarToggle(
                  icon: Icons.lock_outline,
                  label: _document.isProtected ? 'Unprotect' : 'Protect',
                  value: _document.isProtected,
                  onChanged: (_) =>
                      _document.capabilities.canProtect ? _toggleProtection() : null,
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
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Icon(
            _diagnostics.any((d) => d.severity == DiagnosticSeverity.error)
                ? Icons.error_outline
                : Icons.check_circle_outline,
            color: _diagnostics.any((d) => d.severity == DiagnosticSeverity.error)
                ? Colors.red
                : Colors.green,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusText,
              style: TextStyle(
                color: _diagnostics.any((d) => d.severity == DiagnosticSeverity.error)
                    ? Colors.red
                    : Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButton<ScriptDocumentType>(
            value: _document.type,
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
                _document = _document.copyWith(type: value);
                _statusText = 'Tipo actualizado a ${value.name}';
              });
            },
          ),
          const SizedBox(width: 12),
          Text('IntelliSense: ${_settings.enableIntelliSense ? 'On' : 'Off'}'),
          const SizedBox(width: 16),
          Text('Outlining: ${_settings.enableOutlining ? 'On' : 'Off'}'),
          const SizedBox(width: 16),
          Text('Runtime: ${_runtimeState.name}${_lastStartAt != null ? ' · ${_lastStartAt!.toLocal()}' : ''}'),
        ],
      ),
    );
  }

  Widget _buildEditorArea(ThemeData theme) {
    final lines = _codeController.text.split('\n');
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                'Script: ${_document.name}',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              if (_isSaving)
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 6),
                    Text('Guardando...'),
                  ],
                )
              else if (_document.lastSavedAt != null)
                Text(
                  'Último guardado: ${_document.lastSavedAt!.toLocal()}',
                  style: const TextStyle(fontSize: 11),
                ),
              const SizedBox(width: 12),
              Icon(
                _document.isProtected ? Icons.lock : Icons.lock_open,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(_document.isProtected ? 'Protected' : 'Editable'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_settings.showLineNumbers)
                    Container(
                      width: 60,
                      color: Colors.grey.shade100,
                      child: ListView.builder(
                        controller: _editorScrollController,
                        itemCount: lines.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final lineNumber = index + 1;
                          final hasBreakpoint = _breakpoints.contains(lineNumber);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (hasBreakpoint) {
                                  _breakpoints.remove(lineNumber);
                                } else {
                                  _breakpoints.add(lineNumber);
                                }
                              });
                            },
                            child: Container(
                              color: hasBreakpoint
                                  ? Colors.red.shade50
                                  : Colors.transparent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                children: [
                                  if (hasBreakpoint)
                                    const Icon(Icons.circle, size: 8, color: Colors.red),
                                  Expanded(
                                    child: Text(
                                      '$lineNumber',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontFamily: 'Cascadia Mono',
                                        fontSize: 11,
                                        color: hasBreakpoint
                                            ? Colors.red
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      scrollController: _editorScrollController,
                      readOnly: _document.isProtected,
                      maxLines: null,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                      ),
                      style: TextStyle(
                        fontFamily: _settings.fontFamily,
                        fontSize: _settings.fontSize,
                      ),
                      onTap: _updateCursorStatus,
                      onEditingComplete: _updateCursorStatus,
                    ),
                  ),
                ],
              ),
              if (_document.isProtected)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withOpacity(0.8),
                    child: const Center(
                      child: Text('Código protegido. Usa "Unprotect" para editar.'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
        final binding = _bindings[variable.name];
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
            width: 180,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Start Value',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => variable.startValue = value,
                ),
                const SizedBox(height: 4),
                Text(
                  binding?.targetPath?.isNotEmpty == true
                      ? 'Bound to ${binding!.targetPath}'
                      : 'Sin binding',
                  style: const TextStyle(fontSize: 10),
                ),
              ],
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
                : diag.severity == DiagnosticSeverity.warning
                    ? Icons.warning
                    : Icons.info_outline,
            color: diag.severity == DiagnosticSeverity.error
                ? Colors.red
                : diag.severity == DiagnosticSeverity.warning
                    ? Colors.orange
                    : Colors.blue,
          ),
          title: Text(diag.message),
          subtitle: Text('Línea ${diag.line}, Col ${diag.column}'),
          onTap: () => _navigateToLine(diag.line, diag.column),
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
                    _clipboardHistory.removeWhere((entry) => !entry.pinned);
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
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            IconButton(
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
                            IconButton(
                              icon: const Icon(Icons.keyboard_double_arrow_left),
                              tooltip: 'Insertar en el editor',
                              onPressed: () => _insertClipboardEntry(entry.content),
                            ),
                          ],
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
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Expanded(
            child: _CodeLibraryList(
              title: 'System Provided (read-only)',
              folders: _codeLibrary.systemFolders,
              onInsert: (entry) => _insertClipboardEntry('// ${entry.name}\n'),
              onAddEntry: null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CodeLibraryList(
              title: 'Mis snippets',
              folders: _codeLibrary.folders,
              onInsert: (entry) => _insertClipboardEntry('// ${entry.name}\n'),
              onAddEntry: (folder) => _addEntryToFolder(folder),
              onRenameFolder: (folder, newName) => setState(() {
                _codeLibrary.renameFolder(folder, newName);
              }),
              onDeleteEntry: (folder, entry) => setState(() {
                _codeLibrary.deleteEntry(folder, entry);
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _addEntryToFolder(_CodeLibraryFolder folder) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Nuevo snippet'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nombre del snippet'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _codeLibrary.addEntry(folder, controller.text);
                });
                Navigator.pop(context);
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBindingsPanel(ThemeData theme) {
    if (_variables.isEmpty) {
      return Center(
        child: Text(
          'Bindings se generan desde las variables declaradas',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          color: theme.colorScheme.surface,
          child: const Text('Bindings'),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: _variables.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final variable = _variables[index];
              final binding = _bindings[variable.name]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(variable.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'Target path',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(text: binding.targetPath),
                          onChanged: (value) =>
                              _updateBinding(variable.name, value, binding.direction),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: binding.direction,
                        items: const [
                          DropdownMenuItem(value: 'input', child: Text('Input')),
                          DropdownMenuItem(value: 'output', child: Text('Output')),
                          DropdownMenuItem(value: 'bidirectional', child: Text('Bidirectional')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          _updateBinding(variable.name, binding.targetPath, value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Start Value respetado solo si no hay binding activo',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
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
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Variables'),
            Tab(text: 'Check'),
            Tab(text: 'Clipboard'),
            Tab(text: 'Library'),
          ],
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
    );
  }

  void _focusQuickAction(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label)),
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
  final ValueChanged<bool?>? onChanged;

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
    required this.folders,
    required this.onInsert,
    this.onAddEntry,
    this.onRenameFolder,
    this.onDeleteEntry,
  });

  final String title;
  final List<_CodeLibraryFolder> folders;
  final void Function(_CodeLibraryEntry entry) onInsert;
  final void Function(_CodeLibraryFolder folder)? onAddEntry;
  final void Function(_CodeLibraryFolder folder, String newName)? onRenameFolder;
  final void Function(_CodeLibraryFolder folder, _CodeLibraryEntry entry)?
      onDeleteEntry;

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
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  return ExpansionTile(
                    title: Text(folder.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!folder.isReadOnly && onRenameFolder != null)
                          IconButton(
                            icon: const Icon(Icons.drive_file_rename_outline),
                            onPressed: () async {
                              final controller =
                                  TextEditingController(text: folder.name);
                              final newName = await showDialog<String>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Renombrar carpeta'),
                                  content: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, controller.text),
                                      child: const Text('Guardar'),
                                    ),
                                  ],
                                ),
                              );
                              if (newName != null && newName.isNotEmpty) {
                                onRenameFolder!(folder, newName);
                              }
                            },
                          ),
                        if (!folder.isReadOnly && onAddEntry != null)
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => onAddEntry!(folder),
                          ),
                      ],
                    ),
                    children: [
                      for (final entry in folder.entries)
                        ListTile(
                          title: Text(entry.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.keyboard_double_arrow_left),
                                tooltip: 'Insertar en editor',
                                onPressed: () => onInsert(entry),
                              ),
                              if (!folder.isReadOnly && onDeleteEntry != null)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => onDeleteEntry!(folder, entry),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _ScriptBinding {
  const _ScriptBinding({
    required this.variableName,
    this.targetPath,
    this.direction = 'input',
  });

  final String variableName;
  final String? targetPath;
  final String direction;

  _ScriptBinding copyWith({String? targetPath, String? direction}) {
    return _ScriptBinding(
      variableName: variableName,
      targetPath: targetPath ?? this.targetPath,
      direction: direction ?? this.direction,
    );
  }
}

class _ScriptDocument {
  const _ScriptDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.content,
    required this.isDirty,
    required this.isProtected,
    required this.lastSavedAt,
    required this.capabilities,
  });

  final String id;
  final String name;
  final ScriptDocumentType type;
  final String content;
  final bool isDirty;
  final bool isProtected;
  final DateTime? lastSavedAt;
  final _ScriptCapabilities capabilities;

  _ScriptDocument copyWith({
    String? id,
    String? name,
    ScriptDocumentType? type,
    String? content,
    bool? isDirty,
    bool? isProtected,
    DateTime? lastSavedAt,
    _ScriptCapabilities? capabilities,
  }) {
    return _ScriptDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      content: content ?? this.content,
      isDirty: isDirty ?? this.isDirty,
      isProtected: isProtected ?? this.isProtected,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}

class _ScriptCapabilities {
  const _ScriptCapabilities({
    required this.canRun,
    required this.canDebug,
    required this.canProtect,
    required this.canImportPE,
    required this.canConvertPE,
  });

  final bool canRun;
  final bool canDebug;
  final bool canProtect;
  final bool canImportPE;
  final bool canConvertPE;
}

class _EditorSettings {
  const _EditorSettings({
    required this.showLineNumbers,
    required this.enableIntelliSense,
    required this.enableOutlining,
    required this.fontFamily,
    required this.fontSize,
    required this.importPath,
    required this.exportPath,
  });

  final bool showLineNumbers;
  final bool enableIntelliSense;
  final bool enableOutlining;
  final String fontFamily;
  final double fontSize;
  final String importPath;
  final String exportPath;

  factory _EditorSettings.defaults() {
    return const _EditorSettings(
      showLineNumbers: true,
      enableIntelliSense: true,
      enableOutlining: true,
      fontFamily: 'Cascadia Code',
      fontSize: 13,
      importPath: 'C:/Ascend/Import',
      exportPath: 'C:/Ascend/Export',
    );
  }

  _EditorSettings copyWith({
    bool? showLineNumbers,
    bool? enableIntelliSense,
    bool? enableOutlining,
    String? fontFamily,
    double? fontSize,
    String? importPath,
    String? exportPath,
  }) {
    return _EditorSettings(
      showLineNumbers: showLineNumbers ?? this.showLineNumbers,
      enableIntelliSense: enableIntelliSense ?? this.enableIntelliSense,
      enableOutlining: enableOutlining ?? this.enableOutlining,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      importPath: importPath ?? this.importPath,
      exportPath: exportPath ?? this.exportPath,
    );
  }
}

class _OptionsGeneralTab extends StatelessWidget {
  const _OptionsGeneralTab({required this.settings, required this.onChanged});

  final _EditorSettings settings;
  final ValueChanged<_EditorSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SwitchListTile(
          value: settings.showLineNumbers,
          onChanged: (value) => onChanged(settings.copyWith(showLineNumbers: value)),
          title: const Text('Show line numbers'),
        ),
        SwitchListTile(
          value: settings.enableIntelliSense,
          onChanged: (value) => onChanged(settings.copyWith(enableIntelliSense: value)),
          title: const Text('Enable IntelliSense'),
        ),
        SwitchListTile(
          value: settings.enableOutlining,
          onChanged: (value) => onChanged(settings.copyWith(enableOutlining: value)),
          title: const Text('Enable outlining'),
        ),
      ],
    );
  }
}

class _OptionsFontsTab extends StatelessWidget {
  const _OptionsFontsTab({required this.settings, required this.onChanged});

  final _EditorSettings settings;
  final ValueChanged<_EditorSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Font family'),
          DropdownButton<String>(
            value: settings.fontFamily,
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
                onChanged(settings.copyWith(fontFamily: value));
              }
            },
          ),
          const SizedBox(height: 8),
          const Text('Font size'),
          Slider(
            min: 10,
            max: 18,
            divisions: 8,
            value: settings.fontSize,
            onChanged: (value) => onChanged(settings.copyWith(fontSize: value)),
          ),
        ],
      ),
    );
  }
}

class _OptionsPathsTab extends StatelessWidget {
  const _OptionsPathsTab({required this.settings, required this.onChanged});

  final _EditorSettings settings;
  final ValueChanged<_EditorSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: const Text('Code library path'),
          subtitle: Text(settings.importPath),
          trailing: const Icon(Icons.folder),
          onTap: () => onChanged(settings.copyWith(importPath: '${settings.importPath}/..')),
        ),
        ListTile(
          title: const Text('Import path'),
          subtitle: Text(settings.importPath),
          trailing: const Icon(Icons.file_open),
          onTap: () => onChanged(settings.copyWith(importPath: '${settings.importPath}/import')),
        ),
        ListTile(
          title: const Text('Export path'),
          subtitle: Text(settings.exportPath),
          trailing: const Icon(Icons.file_download),
          onTap: () => onChanged(settings.copyWith(exportPath: '${settings.exportPath}/export')),
        ),
      ],
    );
  }
}

class _CodeLibraryEntry {
  const _CodeLibraryEntry({required this.name});

  final String name;
}

class _CodeLibraryFolder {
  const _CodeLibraryFolder({
    required this.name,
    this.isReadOnly = false,
    this.entries = const [],
  });

  final String name;
  final bool isReadOnly;
  final List<_CodeLibraryEntry> entries;

  _CodeLibraryFolder copyWith({String? name, List<_CodeLibraryEntry>? entries}) {
    return _CodeLibraryFolder(
      name: name ?? this.name,
      isReadOnly: isReadOnly,
      entries: entries ?? this.entries,
    );
  }
}

class _CodeLibrary {
  _CodeLibrary({
    required this.systemFolders,
    required this.folders,
  });

  final List<_CodeLibraryFolder> systemFolders;
  final List<_CodeLibraryFolder> folders;

  void addEntry(_CodeLibraryFolder folder, String name) {
    final idx = folders.indexOf(folder);
    if (idx == -1 || name.isEmpty) return;
    final updatedEntries = List<_CodeLibraryEntry>.from(folder.entries)
      ..add(_CodeLibraryEntry(name: name));
    folders[idx] = folder.copyWith(entries: updatedEntries);
  }

  void deleteEntry(_CodeLibraryFolder folder, _CodeLibraryEntry entry) {
    final idx = folders.indexOf(folder);
    if (idx == -1) return;
    final updatedEntries = List<_CodeLibraryEntry>.from(folder.entries)
      ..remove(entry);
    folders[idx] = folder.copyWith(entries: updatedEntries);
  }

  void renameFolder(_CodeLibraryFolder folder, String newName) {
    final idx = folders.indexOf(folder);
    if (idx == -1 || newName.isEmpty) return;
    folders[idx] = folder.copyWith(name: newName);
  }
}
