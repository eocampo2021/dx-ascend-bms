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

      expect(find.text('Idle'), findsOneWidget);
      expect(find.textContaining('Línea Sin datos'), findsOneWidget);
      expect(find.textContaining('TS Sin datos'), findsOneWidget);

      runtimeController.add(const RuntimeStatus(
        isRunning: true,
        currentLine: 7,
        currentTimestamp: 42,
      ));
      await tester.pump();

      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Línea 7 · TS 42'), findsOneWidget);

      runtimeController.add(const RuntimeStatus(
        isRunning: false,
        currentLine: 11,
        currentTimestamp: null,
      ));
      await tester.pump();

      expect(find.text('Idle'), findsOneWidget);
      expect(find.text('Línea 11 · TS Sin datos'), findsOneWidget);

      await runtimeController.close();
    });
  });
}
