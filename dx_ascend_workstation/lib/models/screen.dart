class Screen {
  final int id;
  final String name;
  final String route;
  final String? description;
  final bool enabled;

  Screen({
    required this.id,
    required this.name,
    required this.route,
    this.description,
    this.enabled = true,
  });

  factory Screen.fromJson(Map<String, dynamic> json) {
    return Screen(
      id: json['id'],
      name: json['name'],
      route: json['route'],
      description: json['description'],
      enabled: (json['enabled'] ?? 1) == 1,
    );
  }
}
