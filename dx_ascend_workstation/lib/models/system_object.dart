class SystemObject {
  final int id;
  final int? parentId;
  final String name;
  final String type; // 'folder', 'server', 'program', 'screen'
  String properties; // JSON String

  SystemObject({
    required this.id,
    this.parentId,
    required this.name,
    required this.type,
    required this.properties,
  });

  factory SystemObject.fromJson(Map<String, dynamic> json) {
    return SystemObject(
      id: json['id'],
      parentId: json['parent_id'],
      name: json['name'],
      type: json['type'],
      properties: json['properties'] ?? '{}',
    );
  }
}
