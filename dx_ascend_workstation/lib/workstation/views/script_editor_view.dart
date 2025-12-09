import 'package:flutter/material.dart';

class ScriptEditorView extends StatelessWidget {
  const ScriptEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          color: Colors.white,
          child: Row(
            children: const [
              Icon(Icons.check, size: 16, color: Colors.green),
              SizedBox(width: 4),
              Text("Compilation OK",
                  style:
                      TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              Spacer(),
              Text("Line 1, Col 1", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            alignment: Alignment.topLeft,
            child: const Text(
              "Numeric Input1, Input2\nNumeric Output\n\n  Output = Input1 + Input2\n  print(Output)\n\nEnd",
              style: TextStyle(fontFamily: 'Courier New', fontSize: 13, height: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
