import 'dart:convert';

class SystemObject {
  final int id;
  final int? parentId;
  final String name;
  final String type; // 'folder', 'server', 'program', 'screen'
  final Map<String, dynamic> properties; // JSON Map
  final String rawProperties;
  List<SystemObject> children;
  bool isExpanded;

  SystemObject({
    required this.id,
    this.parentId,
    required this.name,
    required this.type,
    Map<String, dynamic>? properties,
    this.rawProperties = '{}',
    List<SystemObject>? children,
    this.isExpanded = false,
  })  : properties = properties ?? <String, dynamic>{},
        children = children ?? [];

  factory SystemObject.fromJson(Map<String, dynamic> json) {
    final rawProps = json['properties'] ?? '{}';
    Map<String, dynamic> parsedProps = {};
    if (rawProps is Map<String, dynamic>) {
      parsedProps = rawProps;
    } else if (rawProps is String) {
      try {
        final decoded = jsonDecode(rawProps);
        if (decoded is Map<String, dynamic>) {
          parsedProps = decoded;
        }
      } catch (_) {
        parsedProps = {};
      }
    }

    return SystemObject(
      id: json['id'],
      parentId: json['parent_id'],
      name: json['name'],
      type: (json['type'] ?? 'Unknown').toString(),
      properties: parsedProps,
      rawProperties: rawProps.toString(),
    );
  }

  int? get screenId {
    final value = properties['screenId'] ?? properties['screen_id'];
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? get screenRoute {
    final value = properties['route'] ?? properties['screenRoute'];
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}
