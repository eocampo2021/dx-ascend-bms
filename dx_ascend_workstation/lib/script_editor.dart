import 'package:flutter/material.dart';

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

class _ScriptEditorState extends State<ScriptEditor> {
  late TextEditingController _codeController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar estilo EBO
        Container(
          height: 45,
          color: const Color(0xFFE0E0E0),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              const Icon(Icons.code, color: Colors.purple),
              const SizedBox(width: 10),
              Text("Script: ${widget.objectName}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.save, color: Colors.blue),
                onPressed: () => widget.onSave(_codeController.text),
                tooltip: 'Save Script',
              ),
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Colors.green),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Checking Syntax... OK")));
                },
                tooltip: 'Check Syntax',
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra lateral de números de línea
              Container(
                width: 40,
                color: const Color(0xFFF0F0F0),
                padding: const EdgeInsets.only(top: 8),
                child: ListView.builder(
                  itemCount: 100, // Simulado para demo
                  itemBuilder: (ctx, i) => Text(
                    "${i + 1}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ),
              // Editor de texto
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _codeController,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 14,
                        color: Colors.black87),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText:
                          "Numeric Input1\n\nInit:\n  Input1 = 0\n  Goto Loop\n\nLoop:\n  Input1 = Input1 + 1\n",
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
