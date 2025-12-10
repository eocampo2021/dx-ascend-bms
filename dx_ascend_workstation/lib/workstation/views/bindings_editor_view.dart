import 'package:flutter/material.dart';

import '../../models/system_object.dart';
import '../models/binding_assignment.dart';

class BindingsEditorView extends StatefulWidget {
  const BindingsEditorView({
    super.key,
    required this.systemObject,
    required this.availableValues,
    required this.onSave,
  });

  final SystemObject systemObject;
  final List<SystemObject> availableValues;
  final Future<void> Function(List<BindingAssignment>) onSave;

  @override
  State<BindingsEditorView> createState() => _BindingsEditorViewState();
}

class _BindingsEditorViewState extends State<BindingsEditorView> {
  late List<BindingAssignment> _bindings;

  @override
  void initState() {
    super.initState();
    _bindings = _loadBindings();
  }

  List<BindingAssignment> _loadBindings() {
    final rawBindings = widget.systemObject.properties['bindings'];
    if (rawBindings is List) {
      return rawBindings
          .whereType<Map<String, dynamic>>()
          .map((json) => BindingAssignment.fromJson(json, widget.availableValues))
          .toList();
    }
    return <BindingAssignment>[];
  }

  void _addBinding() {
    setState(() {
      _bindings.add(BindingAssignment());
    });
  }

  void _removeBinding(int index) {
    setState(() {
      _bindings.removeAt(index);
    });
  }

  Future<void> _save() async {
    await widget.onSave(_bindings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bindings guardados')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Bindings para ${widget.systemObject.name}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Asocia valores a slots del objeto seleccionado'),
          trailing: ElevatedButton.icon(
            onPressed: _addBinding,
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _bindings.isEmpty
              ? const Center(child: Text('No hay bindings definidos'))
              : ListView.separated(
                  itemBuilder: (context, index) {
                    final binding = _bindings[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButton<SystemObject?>(
                                    isExpanded: true,
                                    value: binding.target,
                                    hint: const Text('Seleccionar valor'),
                                    onChanged: (value) => setState(() {
                                      binding.target = value;
                                    }),
                                    items: widget.availableValues
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text('${value.name} (${value.type})'),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar binding',
                                  onPressed: () => _removeBinding(index),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: TextEditingController(text: binding.slot),
                              decoration: const InputDecoration(
                                labelText: 'Slot',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) => binding.slot = value,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: _bindings.length,
                  padding: const EdgeInsets.all(8.0),
                ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _bindings.isEmpty ? null : _save,
            icon: const Icon(Icons.save),
            label: const Text('Guardar bindings'),
          ),
        ),
      ],
    );
  }
}
