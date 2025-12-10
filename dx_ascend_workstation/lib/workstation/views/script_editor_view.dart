import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/system_object.dart';

class ScriptEditorView extends StatefulWidget {
  const ScriptEditorView({
    super.key,
    required this.systemObject,
    this.onLoad,
    this.onSave,
    this.onCodeChanged,
  });

  final SystemObject systemObject;
  final Future<String?> Function(SystemObject object)? onLoad;
  final Future<void> Function(SystemObject object, String code)? onSave;
  final ValueChanged<String>? onCodeChanged;

  @override
  State<ScriptEditorView> createState() => _ScriptEditorViewState();
}

class _ScriptEditorViewState extends State<ScriptEditorView> {
  late final PlainEnglishEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

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
    _loadScript();
  }

  @override
  void didUpdateWidget(covariant ScriptEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.systemObject.id != widget.systemObject.id) {
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

    try {
      if (widget.onSave != null) {
        await widget.onSave!(widget.systemObject, code);
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
        ),
      ],
    );
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
