import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/system_object.dart';

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
        _stringController.text = rawValue?.toString() ?? '';
        _boolValue = false;
        break;
    }
    setState(() {});
  }

  Future<void> _handleSave() async {
    final Map<String, dynamic> newProps = Map.from(widget.object.properties);
    newProps['status'] = _status;
    newProps['forceStatus'] = _forceStatus;
    newProps['bindingActive'] = _bindingActive;

    switch (_kind) {
      case 'digital':
        newProps['value'] = _boolValue;
        break;
      case 'analog':
        newProps['value'] = double.tryParse(_numericController.text) ?? 0.0;
        break;
      default:
        newProps['value'] = _stringController.text;
        break;
    }

    await widget.onSave(newProps);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dropdownField(
          label: 'Status',
          value: _status,
          items: const ['Enabled', 'Disabled'],
          onChanged: (value) => setState(() => _status = value ?? _status),
        ),
        const SizedBox(height: 8),
        _dropdownField(
          label: 'Force',
          value: _forceStatus,
          items: const ['Not Forced', 'Forced'],
          onChanged: (value) => setState(() => _forceStatus = value ?? _forceStatus),
        ),
        const Divider(height: 24),
        const Text('Valor actual', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildValueEditor(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Guardar propiedades'),
            onPressed: _handleSave,
          ),
        ),
      ],
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: items
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: onChanged,
          ),
        )
      ],
    );
  }

  Widget _buildValueEditor() {
    switch (_kind) {
      case 'digital':
        return SwitchListTile(
          dense: true,
          title: const Text('Valor digital'),
          value: _boolValue,
          onChanged: _canEditValue ? (v) => setState(() => _boolValue = v) : null,
        );
      case 'analog':
        return TextField(
          controller: _numericController,
          enabled: _canEditValue,
          decoration: const InputDecoration(
            labelText: 'Valor numérico',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
        );
      default:
        return TextField(
          controller: _stringController,
          enabled: _canEditValue,
          decoration: const InputDecoration(
            labelText: 'Valor de texto',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        );
    }
  }
}
