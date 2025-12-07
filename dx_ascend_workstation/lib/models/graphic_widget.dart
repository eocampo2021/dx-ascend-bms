import 'dart:convert';

class GraphicWidget {
  final int id;
  final int screenId;
  final String type;
  final String name;
  final int x;
  final int y;
  final int width;
  final int height;
  final Map<String, dynamic> config;

  GraphicWidget({
    required this.id,
    required this.screenId,
    required this.type,
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    Map<String, dynamic>? config,
  }) : config = config ?? <String, dynamic>{};

  factory GraphicWidget.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedConfig = {};
    final cfg = json['config_json'];
    if (cfg is Map<String, dynamic>) {
      parsedConfig = cfg;
    } else if (cfg is String) {
      try {
        final decoded = jsonDecode(cfg);
        if (decoded is Map<String, dynamic>) {
          parsedConfig = decoded;
        }
      } catch (_) {
        parsedConfig = {};
      }
    }

    return GraphicWidget(
      id: json['id'],
      screenId: json['screen_id'],
      type: json['type'],
      name: json['name'],
      x: json['x'] ?? 0,
      y: json['y'] ?? 0,
      width: json['width'] ?? 100,
      height: json['height'] ?? 100,
      config: parsedConfig,
    );
  }

  GraphicWidget copyWith({
    int? id,
    int? screenId,
    String? type,
    String? name,
    int? x,
    int? y,
    int? width,
    int? height,
    Map<String, dynamic>? config,
  }) {
    return GraphicWidget(
      id: id ?? this.id,
      screenId: screenId ?? this.screenId,
      type: type ?? this.type,
      name: name ?? this.name,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      config: config ?? this.config,
    );
  }
}
