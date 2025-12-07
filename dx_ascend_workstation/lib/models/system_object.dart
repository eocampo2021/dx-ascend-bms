class SystemObject {
  final int id;
  final int? parentId;
  final String name;
  final String type; // 'folder', 'server', 'program', 'screen'
  final String properties; // JSON String
  List<SystemObject> children;
  bool isExpanded;

  SystemObject({
    required this.id,
    this.parentId,
    required this.name,
    required this.type,
    String? properties,
    List<SystemObject>? children,
    this.isExpanded = false,
  })  : properties = properties ?? '{}',
        children = children ?? [];

  factory SystemObject.fromJson(Map<String, dynamic> json) {
    return SystemObject(
      id: json['id'],
      parentId: json['parent_id'],
      name: json['name'],
      type: json['type'] ?? 'Unknown',
      properties: json['properties'] ?? '{}',
    );
  }
}
