import 'dart:math';
import 'package:flutter/material.dart';

/// Modelo interno simple para edición
class EditableWidget {
  final int id;
  final String name;
  final String type;
  double x;
  double y;
  double width;
  double height;
  final dynamic configJson;

  EditableWidget({
    required this.id,
    required this.name,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.configJson,
  });

  EditableWidget copy() => EditableWidget(
        id: id,
        name: name,
        type: type,
        x: x,
        y: y,
        width: width,
        height: height,
        configJson: configJson,
      );
}

/// Editor visual de una pantalla: canvas + widgets arrastrables / redimensionables
class ScreenDesigner extends StatefulWidget {
  /// Lista de widgets tal como vienen del server:
  /// [{id, name, type, x, y, width, height, config_json}, ...]
  final List<Map<String, dynamic>> widgets;

  /// Callback cuando cambian posición/tamaño.
  /// Recibe un Map con los mismos campos que el server espera en PUT /api/widgets/:id
  final void Function(Map<String, dynamic> updatedWidget) onWidgetChanged;

  /// Callbacks opcionales para selección.
  final void Function(int widgetId)? onWidgetSelected;
  final int? selectedWidgetId;

  /// Tamaño lógico del canvas (coincide con lo que usa el runtime web)
  final double canvasWidth;
  final double canvasHeight;

  const ScreenDesigner({
    Key? key,
    required this.widgets,
    required this.onWidgetChanged,
    this.canvasWidth = 800,
    this.canvasHeight = 450,
    this.onWidgetSelected,
    this.selectedWidgetId,
  }) : super(key: key);

  @override
  State<ScreenDesigner> createState() => _ScreenDesignerState();
}

class _ScreenDesignerState extends State<ScreenDesigner> {
  late List<EditableWidget> _localWidgets;

  @override
  void initState() {
    super.initState();
    _syncFromProps();
  }

  @override
  void didUpdateWidget(covariant ScreenDesigner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.widgets != widget.widgets) {
      _syncFromProps();
    }
  }

  void _syncFromProps() {
    _localWidgets = widget.widgets.map((w) {
      return EditableWidget(
        id: (w['id'] as num).toInt(),
        name: (w['name'] ?? '').toString(),
        type: (w['type'] ?? 'text').toString(),
        x: ((w['x'] ?? 0) as num).toDouble(),
        y: ((w['y'] ?? 0) as num).toDouble(),
        width: ((w['width'] ?? 120) as num).toDouble(),
        height: ((w['height'] ?? 80) as num).toDouble(),
        configJson: w['config_json'],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;

        if (maxW <= 0 || maxH <= 0) {
          return const SizedBox.shrink();
        }

        final scale = min(
          maxW / widget.canvasWidth,
          maxH / widget.canvasHeight,
        );

        return Center(
          child: Container(
            width: widget.canvasWidth * scale,
            height: widget.canvasHeight * scale,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 22,
                  offset: Offset(0, 16),
                ),
              ],
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF10151E),
                  Color(0xFF05070C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                // grid suave de fondo
                CustomPaint(
                  size: Size(
                      widget.canvasWidth * scale, widget.canvasHeight * scale),
                  painter: _GridPainter(scale: scale),
                ),
                // widgets
                for (final w in _localWidgets)
                  _buildWidgetBox(context, w, scale),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWidgetBox(BuildContext context, EditableWidget w, double scale) {
    final left = w.x * scale;
    final top = w.y * scale;
    final width = w.width * scale;
    final height = w.height * scale;

    final isSelected = widget.selectedWidgetId == w.id;

    Color borderColor;
    switch (w.type) {
      case 'bar':
        borderColor = const Color(0xFF00F5C7);
        break;
      case 'gauge':
        borderColor = const Color(0xFF3BF57A);
        break;
      case 'indicator':
        borderColor = const Color(0xFF9EFF57);
        break;
      case 'fan':
        borderColor = const Color(0xFF4DD0E1);
        break;
      default:
        borderColor = Colors.white.withOpacity(0.55);
        break;
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: () => widget.onWidgetSelected?.call(w.id),
        onPanStart: (_) => widget.onWidgetSelected?.call(w.id),
        onPanUpdate: (details) {
          setState(() {
            w.x += details.delta.dx / scale;
            w.y += details.delta.dy / scale;
            w.x = w.x.clamp(0.0, widget.canvasWidth - w.width);
            w.y = w.y.clamp(0.0, widget.canvasHeight - w.height);
          });
        },
        onPanEnd: (_) => _emitChange(w),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? Colors.amberAccent : borderColor,
                  width: isSelected ? 2.0 : 1.1,
                ),
                gradient: const LinearGradient(
                  colors: [
                    Color(0x22FFFFFF),
                    Color(0x88000000),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black87,
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        w.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.06,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '[${w.type.toUpperCase()}]',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'x=${w.x.toStringAsFixed(0)}  y=${w.y.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  Text(
                    'w=${w.width.toStringAsFixed(0)}  h=${w.height.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            // handle de resize
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    w.width += details.delta.dx / scale;
                    w.height += details.delta.dy / scale;
                    w.width = max(40, w.width);
                    w.height = max(30, w.height);
                    w.width = min(w.width, widget.canvasWidth - w.x);
                    w.height = min(w.height, widget.canvasHeight - w.y);
                  });
                },
                onPanEnd: (_) => _emitChange(w),
                child: Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 2, bottom: 2),
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.only(topLeft: Radius.circular(10)),
                    color: borderColor,
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withOpacity(0.8),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _emitChange(EditableWidget w) {
    widget.onWidgetChanged({
      'id': w.id,
      'name': w.name,
      'type': w.type,
      'x': w.x,
      'y': w.y,
      'width': w.width,
      'height': w.height,
      'config_json': w.configJson ?? {},
    });
  }
}

/// Grid suave de fondo (tipo editor EBO)
class _GridPainter extends CustomPainter {
  final double scale;

  _GridPainter({required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1.0;

    const grid = 32.0;
    for (double x = 0; x <= size.width; x += grid * scale) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += grid * scale) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.scale != scale;
}
