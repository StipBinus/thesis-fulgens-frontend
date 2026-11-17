import 'package:flutter/material.dart';

// Home payload models, shared by the provider and the page.

/// GET /home/profile
class UserProfileData {
  const UserProfileData({
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

  /// Premium currency (coins), shown in the top-right pill.
  final int userCurrency;

  /// Shop currency (Shine), spent in the parent shop.
  final int parentCurrency;

  /// Money balance in Rupiah, shown in the sheet.
  final int userBalance;

  /// Consecutive days streak.
  final int userStreak;

  /// XP needed per level (used by the small progress bar).
  static const int xpToNextLevel = 10;

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      profilePicture: json['profilePicture'] as String?,
      name: json['name'] as String? ?? '',
      userCurrency: (json['userCurrency'] as num?)?.toInt() ?? 0,
      parentCurrency: (json['parentCurrency'] as num?)?.toInt() ?? 0,
      userBalance: (json['userBalance'] as num?)?.toInt() ?? 0,
      userStreak: (json['userStreak'] as num?)?.toInt() ?? 0,
    );
  }

  // Local overlays (logbook rewards / pockets) keep the dummy profile intact.
  UserProfileData copyWith({
    int? userCurrency,
    int? userBalance,
    int? userStreak,
  }) {
    return UserProfileData(
      profilePicture: profilePicture,
      name: name,
      userCurrency: userCurrency ?? this.userCurrency,
      parentCurrency: parentCurrency,
      userBalance: userBalance ?? this.userBalance,
      userStreak: userStreak ?? this.userStreak,
    );
  }
}

/// GET /home/event
class EventData {
  const EventData({required this.eventName, required this.endsIn});

  final String eventName;
  final String endsIn;

  factory EventData.fromJson(Map<String, dynamic> json) {
    return EventData(
      eventName: json['eventName'] as String? ?? 'No event',
      endsIn: json['endsIn'] as String? ?? '-',
    );
  }
}

/// GET /home/missions
class DailyMission {
  const DailyMission({
    required this.title,
    required this.completed,
    this.icon = Icons.edit_outlined,
  });

  final String title;
  final bool completed;
  final IconData icon;

  factory DailyMission.fromJson(Map<String, dynamic> json) {
    return DailyMission(
      title: json['title'] as String? ?? '',
      completed: json['completed'] as bool? ?? false,
      icon: Icons.edit_outlined,
    );
  }
}

/// GET /home/goals
class UserGoal {
  const UserGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.saved,
    this.emoji = '\u{1F3AF}',
  });

  final String id;
  final String name;
  final int target;
  final int saved;
  final String emoji;

  double get progress =>
      target <= 0 ? 0 : (saved / target).clamp(0.0, 1.0).toDouble();

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      id: json['id'] is String ? json['id'] as String : '',
      name: json['name'] as String? ?? '',
      target: (json['target'] as num?)?.toInt() ?? 0,
      saved: (json['saved'] as num?)?.toInt() ?? 0,
      emoji: json['emoji'] as String? ?? 'ÃƒÂ°Ã…Â¸Ã…Â½Ã‚Â¯',
    );
  }
}
