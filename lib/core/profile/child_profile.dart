/// Full child profile returned by `GET /api/home/profile/child`.
///
/// Cached in memory and on the device so screens can read it without waiting
/// for another network round-trip.
class ChildProfile {
  const ChildProfile({
    this.profilePicture,
    required this.name,
    required this.userCurrency,
    required this.parentCurrency,
    required this.userBalance,
    required this.userStreak,
  });

  /// Profile picture URL. `null` renders the default person icon.
  final String? profilePicture;

  final String name;

  /// Premium currency (coins).
  final int userCurrency;

  /// Shop currency (Shine), spent in the parent shop.
  final int parentCurrency;

  /// Money balance in Rupiah.
  final int userBalance;

  /// Consecutive days streak.
  final int userStreak;

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      profilePicture: _optionalString(json['profilePicture']),
      name: json['name'] as String? ?? '',
      userCurrency: _intValue(json['userCurrency']),
      parentCurrency: _intValue(json['parentCurrency']),
      userBalance: _intValue(json['userBalance']),
      userStreak: _intValue(json['userStreak']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profilePicture': profilePicture,
      'name': name,
      'userCurrency': userCurrency,
      'parentCurrency': parentCurrency,
      'userBalance': userBalance,
      'userStreak': userStreak,
    };
  }

  ChildProfile copyWith({
    String? profilePicture,
    String? name,
    int? userCurrency,
    int? parentCurrency,
    int? userBalance,
    int? userStreak,
  }) {
    return ChildProfile(
      profilePicture: profilePicture ?? this.profilePicture,
      name: name ?? this.name,
      userCurrency: userCurrency ?? this.userCurrency,
      parentCurrency: parentCurrency ?? this.parentCurrency,
      userBalance: userBalance ?? this.userBalance,
      userStreak: userStreak ?? this.userStreak,
    );
  }
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

String? _optionalString(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
