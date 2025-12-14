import 'dart:async';

import 'package:dx_ascend_workstation/models/system_object.dart';
import 'package:dx_ascend_workstation/workstation/views/script_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScriptEditorView runtime status', () {
    testWidgets('reacts to runtime status stream updates', (tester) async {
      final runtimeController = StreamController<RuntimeStatus>();
      final scriptObject = SystemObject(
        id: 1,
        name: 'Test Script',
        type: 'script',
        properties: {'code': 'Input A\nEnd'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: ScriptEditorView(
              systemObject: scriptObject,
              availableValues: const [],
              runtimeStatusStream: runtimeController.stream,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Programas detenidos'), findsOneWidget);
      expect(find.textContaining('Línea sin datos'), findsOneWidget);
      expect(find.textContaining('TS sin datos'), findsOneWidget);
      expect(scriptObject.isRunning, isFalse);
      expect(scriptObject.isHalted, isFalse);
      expect(scriptObject.runtimeState, 'stopped');

      runtimeController.add(const RuntimeStatus(
        isRunning: true,
        currentLine: 7,
        currentTimestamp: 42,
      ));
      await tester.pump();

      expect(find.text('Programas corriendo'), findsOneWidget);
      expect(find.text('Línea 7 · TS 42'), findsOneWidget);
      expect(scriptObject.isRunning, isTrue);
      expect(scriptObject.isHalted, isFalse);
      expect(scriptObject.runtimeState, 'running');

      runtimeController.add(const RuntimeStatus(
        isRunning: false,
        currentLine: 11,
        currentTimestamp: null,
        programs: [
          ProgramRuntimeStatus(
            id: 1,
            name: 'Test Script',
            isRunning: false,
            isHalted: true,
            errors: ['runtime error'],
          ),
        ],
      ));
      await tester.pump();

      expect(find.textContaining('detenidos por falla'), findsOneWidget);
      expect(find.textContaining('Test Script: runtime error'), findsOneWidget);
      expect(scriptObject.isRunning, isFalse);
      expect(scriptObject.isHalted, isTrue);
      expect(scriptObject.runtimeState, 'halted');

      await runtimeController.close();
    });
  });
}
