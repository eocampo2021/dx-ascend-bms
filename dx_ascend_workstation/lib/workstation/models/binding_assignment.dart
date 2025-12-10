import '../../models/system_object.dart';

/// Represents the association between a value object and a logical slot.
class BindingAssignment {
  BindingAssignment({
    this.target,
    this.slot = '',
  });

  SystemObject? target;
  String slot;

  factory BindingAssignment.fromJson(
    Map<String, dynamic> json,
    List<SystemObject> availableValues,
  ) {
    final targetId = json['target_id'];
    final target = targetId is int
        ? availableValues.firstWhere(
            (value) => value.id == targetId,
            orElse: () => SystemObject(
              id: targetId,
              name: json['valueName']?.toString() ?? 'Value $targetId',
              type: json['targetType']?.toString() ?? 'Value',
            ),
          )
        : null;

    return BindingAssignment(
      target: target,
      slot: (json['slot'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'target_id': target?.id,
      'slot': slot,
      'valueName': target?.name,
    };
  }
}
