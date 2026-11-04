// Models for the child finance endpoints.
//
// - Goal  : GET/POST/PUT/DELETE /api/goals
// - Pocket: GET/POST/PUT/DELETE /api/pocket

class ChildGoal {
  const ChildGoal({
    required this.goalId,
    required this.childId,
    required this.goalsName,
    this.goalsDesc,
    required this.userBalance,
    required this.allocatedBalance,
    required this.goalPrice,
    this.createdAt,
    this.updatedAt,
  });

  final int goalId;
  final String childId;
  final String goalsName;
  final String? goalsDesc;

  /// Balance owned by the child, as reported by the backend.
  final int userBalance;

  /// Money put aside for this goal.
  final int allocatedBalance;

  /// Price of the thing the child is saving for.
  final int goalPrice;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 0.0 - 1.0, based on allocated money over the goal price.
  double get progress =>
      goalPrice <= 0 ? 0 : (allocatedBalance / goalPrice).clamp(0.0, 1.0);

  factory ChildGoal.fromJson(Map<String, dynamic> json) {
    return ChildGoal(
      goalId: _intValue(json['goalId']),
      childId: _stringValue(json['childId']),
      goalsName: _stringValue(json['goalsName']),
      goalsDesc: _optionalString(json['goalsDesc']),
      userBalance: _intValue(json['userBalance']),
      allocatedBalance: _intValue(json['allocatedBalance']),
      goalPrice: _intValue(json['goalPrice']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
    );
  }
}

class ChildPocket {
  const ChildPocket({
    required this.pocketId,
    required this.childId,
    this.pocketImage,
    required this.pocketName,
    this.pocketDesc,
    required this.userBalance,
    required this.allocatedBalance,
    this.createdAt,
    this.updatedAt,
  });

  final int pocketId;
  final String childId;

  /// Emoji or image URL picked by the child.
  final String? pocketImage;

  final String pocketName;
  final String? pocketDesc;

  /// Balance owned by the child, as reported by the backend.
  final int userBalance;

  /// Money assigned to this pocket.
  final int allocatedBalance;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ChildPocket.fromJson(Map<String, dynamic> json) {
    return ChildPocket(
      pocketId: _intValue(json['pocketId']),
      childId: _stringValue(json['childId']),
      pocketImage: _optionalString(json['pocketImage']),
      pocketName: _stringValue(json['pocketName']),
      pocketDesc: _optionalString(json['pocketDesc']),
      userBalance: _intValue(json['userBalance']),
      allocatedBalance: _intValue(json['allocatedBalance']),
      createdAt: _dateValue(json['createdAt']),
      updatedAt: _dateValue(json['updatedAt']),
    );
  }
}

// JSON helpers

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String _stringValue(dynamic value) => value is String ? value : '';

String? _optionalString(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _dateValue(dynamic value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
