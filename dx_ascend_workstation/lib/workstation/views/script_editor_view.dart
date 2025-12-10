import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/system_object.dart';
import '../models/binding_assignment.dart';

class ScriptEditorView extends StatefulWidget {
  const ScriptEditorView({
    super.key,
    required this.systemObject,
    required this.availableValues,
    this.onLoad,
    this.onSave,
    this.onCodeChanged,
    this.onBindingsChanged,
  });

  final SystemObject systemObject;
  final List<SystemObject> availableValues;
  final Future<String?> Function(SystemObject object)? onLoad;
  final Future<void> Function(
    SystemObject object,
    String code,
    List<BindingAssignment> bindings,
  )?
      onSave;
  final ValueChanged<String>? onCodeChanged;
  final ValueChanged<List<BindingAssignment>>? onBindingsChanged;

  @override
  State<ScriptEditorView> createState() => _ScriptEditorViewState();
}

class _ScriptEditorViewState extends State<ScriptEditorView> {
  late final PlainEnglishEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final List<BindingAssignment> _bindings = [];
  List<_PlainEnglishVariable> _ioVariables = const [];

  bool _isValid = true;
  bool _isLoading = false;
  bool _isSaving = false;
  String _statusMessage = 'Compilación OK';
  String _cursorLabel = 'Línea 1, Col 1';

  @override
  void initState() {
    super.initState();
    _controller = PlainEnglishEditingController();
    _controller.addListener(_onCodeChanged);
    _bindings.addAll(_loadExistingBindings());
    _loadScript();
  }

  @override
  void didUpdateWidget(covariant ScriptEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.systemObject.id != widget.systemObject.id) {
      _bindings
        ..clear()
        ..addAll(_loadExistingBindings());
      _loadScript();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onCodeChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadScript() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cargando script...';
    });

    _bindings
      ..clear()
      ..addAll(_loadExistingBindings());

    String code = _extractCodeFromProperties();

    if (widget.onLoad != null) {
      try {
        final remote = await widget.onLoad!(widget.systemObject);
        if (remote != null) {
          code = remote;
        }
      } catch (_) {
        // En caso de error, usamos el código local sin interrumpir la UI
      }
    }

    _controller.text = code;
    _runValidation();
    _syncBindingsWithCode();

    setState(() {
      _isLoading = false;
      _statusMessage = _isValid ? 'Compilación OK' : _statusMessage;
    });
  }

  String _extractCodeFromProperties() {
    final props = widget.systemObject.properties;
    const candidates = ['code', 'script', 'source', 'plainEnglish'];
    for (final key in candidates) {
      final value = props[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  void _onCodeChanged() {
    widget.onCodeChanged?.call(_controller.text);
    _syncBindingsWithCode();
    _updateCursorLabel();
    // Validación rápida en segundo plano
    _runValidation(silent: true);
  }

  void _updateCursorLabel() {
    final selection = _controller.selection;
    int offset = selection.baseOffset;
    if (offset < 0 || offset > _controller.text.length) {
      offset = _controller.text.length;
    }
    final textUntilCursor = _controller.text.substring(0, offset);
    final lines = textUntilCursor.split('\n');
    final line = lines.length;
    final column = lines.isEmpty ? 1 : lines.last.length + 1;
    setState(() {
      _cursorLabel = 'Línea $line, Col $column';
    });
  }

  List<BindingAssignment> _loadExistingBindings() {
    final raw = widget.systemObject.properties['bindings'];
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map((json) => BindingAssignment.fromJson(json, widget.availableValues))
          .toList();
    }
    return <BindingAssignment>[];
  }

  void _syncBindingsWithCode() {
    final detected = _parsePlainEnglishVariables(_controller.text);

    final normalizedExisting = <String, BindingAssignment>{};
    for (final binding in _bindings) {
      normalizedExisting[binding.slot.toLowerCase()] = binding;
    }

    final List<BindingAssignment> updated = [];
    for (final variable in detected) {
      final existing = normalizedExisting.remove(variable.name.toLowerCase());
      updated.add(
        BindingAssignment(
          slot: variable.name,
          direction: variable.kind,
          target: existing?.target,
        ),
      );
    }

    // Preservamos bindings que no están vinculados a Input/Output declarados
    updated.addAll(normalizedExisting.values);

    setState(() {
      _ioVariables = detected;

      _bindings
        ..clear()
        ..addAll(updated);
    });

    widget.onBindingsChanged?.call(_bindings);
  }

  List<_PlainEnglishVariable> _parsePlainEnglishVariables(String code) {
    final regex = RegExp(
      r'^\s*(?:Numeric|String|Boolean)?\s*(Input|Output)\s+([A-Za-z_][A-Za-z0-9_]*)',
      multiLine: true,
      caseSensitive: false,
    );

    final seen = <String>{};
    final variables = <_PlainEnglishVariable>[];

    for (final match in regex.allMatches(code)) {
      final kind = match.group(1)?.toLowerCase();
      final name = match.group(2) ?? '';
      if (name.isEmpty) continue;

      final normalized = name.toLowerCase();
      if (seen.contains(normalized)) continue;

      seen.add(normalized);
      variables.add(_PlainEnglishVariable(name: name, kind: kind));
    }

    return variables;
  }

  void _runValidation({bool silent = false}) {
    final errors = <String>[];
    final code = _controller.text;
    if (code.trim().isEmpty) {
      errors.add('El script está vacío');
    }
    if (!RegExp(r'\bEnd\b', caseSensitive: false).hasMatch(code)) {
      errors.add('Falta la sentencia "End"');
    }
    final lines = code.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      if (line.contains('..')) {
        errors.add('Posible error de sintaxis en la línea ${i + 1}');
      }
    }

    final valid = errors.isEmpty;

    if (!silent || valid != _isValid) {
      setState(() {
        _isValid = valid;
        _statusMessage = valid ? 'Compilación OK' : errors.join(' · ');
      });
    }
  }

  Future<void> _saveScript() async {
    final code = _controller.text;
    setState(() {
      _isSaving = true;
      _statusMessage = 'Guardando script...';
    });

    widget.systemObject.properties['code'] = code;
    widget.systemObject.properties['bindings'] =
        _bindings.map((binding) => binding.toJson()).toList();

    try {
      if (widget.onSave != null) {
        await widget.onSave!(widget.systemObject, code, _bindings);
      }
      if (mounted) {
        setState(() {
          _statusMessage = 'Script guardado';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Script guardado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'No se pudo guardar: $e';
          _isValid = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: 'Courier New',
          fontSize: 13,
          height: 1.4,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Icon(
                _isValid ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: _isValid ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _statusMessage,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isValid ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _cursorLabel,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isSaving || _isLoading ? null : _saveScript,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => _runValidation(silent: false),
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Validar'),
              ),
              const Spacer(),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Scrollbar(
                    controller: _scrollController,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        scrollController: _scrollController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                        ),
                        style: baseStyle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 320,
                  child: _BindingsPanel(
                    ioVariables: _ioVariables,
                    bindings: _bindings,
                    availableValues: widget.availableValues,
                    onBindingChanged: _handleBindingChange,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _handleBindingChange(String slotName, SystemObject? value) {
    final index = _bindings.indexWhere(
        (binding) => binding.slot.toLowerCase() == slotName.toLowerCase());
    if (index == -1) return;

    setState(() {
      _bindings[index].target = value;
      widget.onBindingsChanged?.call(_bindings);
    });
  }
}

class PlainEnglishEditingController extends TextEditingController {
  PlainEnglishEditingController({String? text}) : super(text: text);

  static final RegExp _tokenMatcher = RegExp(
    r'(#.*$|//.*$)|\b(Numeric|Input|Output|Return|If|Else|Then|End|print)\b|\b[0-9]+(?:\.[0-9]+)?\b',
    multiLine: true,
    caseSensitive: false,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    final List<InlineSpan> children = [];
    int start = 0;

    for (final match in _tokenMatcher.allMatches(text)) {
      if (match.start > start) {
        children.add(TextSpan(text: text.substring(start, match.start)));
      }

      TextStyle tokenStyle = const TextStyle();
      final token = match.group(0)!;
      if (match.group(1) != null) {
        tokenStyle = const TextStyle(color: Colors.grey);
      } else if (match.group(2) != null) {
        tokenStyle = const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold);
      } else {
        tokenStyle = const TextStyle(color: Colors.deepPurple);
      }

      children.add(TextSpan(text: token, style: tokenStyle));
      start = match.end;
    }

    if (start < text.length) {
      children.add(TextSpan(text: text.substring(start)));
    }

    return TextSpan(style: style, children: children);
  }
}

class _PlainEnglishVariable {
  _PlainEnglishVariable({required this.name, this.kind});

  final String name;
  final String? kind;
}

class _BindingsPanel extends StatelessWidget {
  const _BindingsPanel({
    required this.ioVariables,
    required this.bindings,
    required this.availableValues,
    required this.onBindingChanged,
  });

  final List<_PlainEnglishVariable> ioVariables;
  final List<BindingAssignment> bindings;
  final List<SystemObject> availableValues;
  final void Function(String slot, SystemObject? value) onBindingChanged;

  BindingAssignment? _findBinding(String slot) {
    return bindings
        .cast<BindingAssignment?>()
        .firstWhere(
          (binding) =>
              binding != null && binding.slot.toLowerCase() == slot.toLowerCase(),
          orElse: () => null,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bindings de PlainEnglish',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Asocia Inputs/Outputs del script con Values del sistema.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const Divider(height: 16),
            if (ioVariables.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Declara "Input" o "Output" para crear bindings'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemBuilder: (context, index) {
                    final variable = ioVariables[index];
                    final binding = _findBinding(variable.name);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Chip(
                              label: Text(
                                (variable.kind ?? 'slot').toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              backgroundColor:
                                  (variable.kind ?? '').toLowerCase() == 'output'
                                      ? Colors.orange
                                      : Colors.blue,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                variable.name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<SystemObject?>(
                          isExpanded: true,
                          value: binding?.target,
                          decoration: const InputDecoration(
                            labelText: 'Value asociado',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<SystemObject?>(
                              value: null,
                              child: Text('Sin binding'),
                            ),
                            ...availableValues.map(
                              (value) => DropdownMenuItem<SystemObject?>(
                                value: value,
                                child: Text('${value.name} (${value.type})'),
                              ),
                            )
                          ],
                          onChanged: (value) => onBindingChanged(
                            variable.name,
                            value,
                          ),
                        ),
                      ],
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: ioVariables.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
