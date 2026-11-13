// Logbook data model

enum LogbookEntryType { expense, income }

// Mirrors the backend TransactionCategory enum.
enum LogbookCategory {
  foodAndBeverage('Food & beverage'),
  transport('Transport'),
  entertainment('Entertainment'),
  school('School'),
  hobby('Hobby'),
  other('Other'),
  allowance('Allowance'),
  gift('Gift');

  const LogbookCategory(this.label);

  final String label;
}

const List<LogbookCategory> logbookExpenseCategories = [
  LogbookCategory.foodAndBeverage,
  LogbookCategory.transport,
  LogbookCategory.entertainment,
  LogbookCategory.school,
  LogbookCategory.hobby,
  LogbookCategory.other,
];

const List<LogbookCategory> logbookIncomeCategories = [
  LogbookCategory.allowance,
  LogbookCategory.gift,
  LogbookCategory.other,
];

List<LogbookCategory> logbookCategoriesFor(LogbookEntryType type) =>
    type == LogbookEntryType.income
        ? logbookIncomeCategories
        : logbookExpenseCategories;

// Backend enum names for `TransactionCategory` / `TransactionType`.
String logbookCategoryApiName(LogbookCategory category) {
  switch (category) {
    case LogbookCategory.foodAndBeverage:
      return 'FOOD_AND_BEVERAGE';
    case LogbookCategory.transport:
      return 'TRANSPORT';
    case LogbookCategory.entertainment:
      return 'ENTERTAINMENT';
    case LogbookCategory.school:
      return 'SCHOOL';
    case LogbookCategory.hobby:
      return 'HOBBY';
    case LogbookCategory.other:
      return 'OTHER';
    case LogbookCategory.allowance:
      return 'ALLOWANCE';
    case LogbookCategory.gift:
      return 'GIFT';
  }
}

LogbookCategory logbookCategoryFromApi(dynamic value) {
  switch (value) {
    case 'FOOD_AND_BEVERAGE':
      return LogbookCategory.foodAndBeverage;
    case 'TRANSPORT':
      return LogbookCategory.transport;
    case 'ENTERTAINMENT':
      return LogbookCategory.entertainment;
    case 'SCHOOL':
      return LogbookCategory.school;
    case 'HOBBY':
      return LogbookCategory.hobby;
    case 'ALLOWANCE':
      return LogbookCategory.allowance;
    case 'GIFT':
      return LogbookCategory.gift;
    default:
      return LogbookCategory.other;
  }
}

String logbookEntryTypeApiName(LogbookEntryType type) =>
    type == LogbookEntryType.income ? 'INCOME' : 'EXPENSE';

LogbookEntryType logbookEntryTypeFromApi(dynamic value) =>
    value == 'INCOME' ? LogbookEntryType.income : LogbookEntryType.expense;

// Old fixed pocket slots. Pockets are now fetched from the backend
// (`GET /api/pocket/child/{childId}`), so entries store a pocket id instead.
// enum PocketSlot {
//   cash('Cash'),
//   snack('Snack'),
//   savings('Savings'),
//   travel('Travel');
//
//   const PocketSlot(this.label);
//
//   final String label;
// }

// Helpers

/// Local calendar key: 2026-10-27
String logbookDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String logbookRupiah(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  final sign = value < 0 ? '-' : '';
  return '${sign}Rp $buffer';
}

String logbookGroup(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  final sign = value < 0 ? '-' : '';
  return '$sign$buffer';
}

// Entry

class LogbookEntry {
  const LogbookEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    // required this.pocket,
    this.pocketId,
    this.pocketName = '',
    this.title = '',
    this.note = '',
  });

  final String id;
  final LogbookEntryType type;
  final int amount;
  final LogbookCategory category;

  // final PocketSlot pocket;

  /// Pocket the money moved through, taken from the backend pocket list.
  final int? pocketId;

  /// Name snapshot so an entry still reads correctly if the pocket is renamed
  /// or removed later.
  final String pocketName;
  final String title;
  final String note;

  bool get isExpense => type == LogbookEntryType.expense;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'category': category.name,
      // 'pocket': pocket.name,
      'pocketId': pocketId,
      'pocketName': pocketName,
      'title': title,
      'note': note,
    };
  }

  factory LogbookEntry.fromJson(Map<String, dynamic> json) {
    return LogbookEntry(
      id: json['id'] as String? ?? '',
      type: LogbookEntryType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => LogbookEntryType.expense,
      ),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      category: LogbookCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => LogbookCategory.other,
      ),
      // pocket: PocketSlot.values.firstWhere(
      //   (value) => value.name == json['pocket'],
      //   orElse: () => PocketSlot.cash,
      // ),
      pocketId: (json['pocketId'] as num?)?.toInt(),
      pocketName: json['pocketName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
    );
  }

  LogbookEntry copyWith({
    String? id,
    LogbookEntryType? type,
    int? amount,
    LogbookCategory? category,
    // PocketSlot? pocket,
    int? pocketId,
    String? pocketName,
    String? title,
    String? note,
  }) {
    return LogbookEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      // pocket: pocket ?? this.pocket,
      pocketId: pocketId ?? this.pocketId,
      pocketName: pocketName ?? this.pocketName,
      title: title ?? this.title,
      note: note ?? this.note,
    );
  }
}

// Day

class LogbookDay {
  const LogbookDay({
    this.clientId = '',
    this.logId,
    this.entries = const [],
    this.note = '',
    this.zeroSpend = false,
    this.completedAt,
    this.rewardClaimed = false,
  });

  /// UUIDv7 created on the device; the row key for sync.
  final String clientId;

  /// Backend `daily_transaction_logs.id` for this date. Null until the day has
  /// been saved through the API.
  final int? logId;

  final List<LogbookEntry> entries;
  final String note;
  final bool zeroSpend;
  final DateTime? completedAt;
  final bool rewardClaimed;

  bool get isLogged => rewardClaimed;

  bool get hasNote => note.trim().isNotEmpty;

  bool get hasMoneyRecord => entries.isNotEmpty || zeroSpend;

  // Streak day: same rule as a green date picker ring.
  bool get countsForStreak => isLogged || hasMoneyRecord;

  bool get qualifies => hasNote && hasMoneyRecord;

  int get totalSpent => entries
      .where((entry) => entry.isExpense)
      .fold(0, (sum, entry) => sum + entry.amount);

  int get totalEarned => entries
      .where((entry) => !entry.isExpense)
      .fold(0, (sum, entry) => sum + entry.amount);

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'logId': logId,
      'entries': entries.map((entry) => entry.toJson()).toList(),
      'note': note,
      'zeroSpend': zeroSpend,
      'completedAt': completedAt?.toIso8601String(),
      'rewardClaimed': rewardClaimed,
    };
  }

  factory LogbookDay.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? const [];
    return LogbookDay(
      clientId: json['clientId'] as String? ?? '',
      logId: (json['logId'] as num?)?.toInt(),
      entries:
          rawEntries
              .map((raw) => LogbookEntry.fromJson(raw as Map<String, dynamic>))
              .toList(),
      note: json['note'] as String? ?? '',
      zeroSpend: json['zeroSpend'] as bool? ?? false,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      rewardClaimed: json['rewardClaimed'] as bool? ?? false,
    );
  }

  LogbookDay copyWith({
    String? clientId,
    int? logId,
    bool clearLogId = false,
    List<LogbookEntry>? entries,
    String? note,
    bool? zeroSpend,
    DateTime? completedAt,
    bool? rewardClaimed,
  }) {
    return LogbookDay(
      clientId: clientId ?? this.clientId,
      logId: clearLogId ? null : (logId ?? this.logId),
      entries: entries ?? this.entries,
      note: note ?? this.note,
      zeroSpend: zeroSpend ?? this.zeroSpend,
      completedAt: completedAt ?? this.completedAt,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
    );
  }
}

// Pockets
//
// The logbook used to keep its own wallet here, seeded with a fixed
// Rp 1.150.000 (500k cash + 300k snack + 200k savings + 150k travel). That
// number had no link to the real balance, so it was removed. The balance now
// comes from the cached profile (`userBalance`) and pockets come from
// `fetchPockets`; see logbook_money.dart.
//
// class PocketWallet {
//   const PocketWallet({required this.amounts});
//
//   final Map<PocketSlot, int> amounts;
//
//   factory PocketWallet.seeded() {
//     return const PocketWallet(
//       amounts: {
//         PocketSlot.cash: 500000,
//         PocketSlot.snack: 300000,
//         PocketSlot.savings: 200000,
//         PocketSlot.travel: 150000,
//       },
//     );
//   }
//
//   int of(PocketSlot slot) => amounts[slot] ?? 0;
//
//   int get total => amounts.values.fold(0, (sum, amount) => sum + amount);
//
//   PocketWallet withAmount(PocketSlot slot, int amount) {
//     return PocketWallet(amounts: {...amounts, slot: amount});
//   }
//
//   Map<String, dynamic> toJson() {
//     return amounts.map((slot, amount) => MapEntry(slot.name, amount));
//   }
//
//   factory PocketWallet.fromJson(Map<String, dynamic> json) {
//     return PocketWallet(
//       amounts: {
//         for (final slot in PocketSlot.values)
//           slot: (json[slot.name] as num?)?.toInt() ?? 0,
//       },
//     );
//   }
// }

// State

class LogbookState {
  const LogbookState({
    required this.days,
    // required this.pockets,
    required this.berries,
    required this.coinsEarned,
    this.loaded = false,
    this.lastClaimKey,
    this.lastClaimCoins = 0,
    this.lastClaimBerries = 0,
  });

  factory LogbookState.seeded() {
    return LogbookState(
      days: const {},
      // pockets: PocketWallet.seeded(),
      berries: 0,
      coinsEarned: 0,
    );
  }

  final Map<String, LogbookDay> days;
  // final PocketWallet pockets;
  final int berries;
  final int coinsEarned;
  final bool loaded;

  /// Last day that paid out, used for the coin/berry burst.
  final String? lastClaimKey;

  // Amount the last claim paid.
  final int lastClaimCoins;
  final int lastClaimBerries;

  static String keyFor(DateTime date) => logbookDateKey(date);

  static String get todayKey => logbookDateKey(DateTime.now());

  LogbookDay dayFor(String key) => days[key] ?? const LogbookDay();

  // Balance as of the end of a day, rebuilt from entries.
  // Removed when the balance moved to the real `userBalance` so the logbook
  // always agrees with the home page. The BALANCE hero now reads
  // logbookMoneyProvider instead.
  //
  // int balanceOn(String key) {
  //   var value = pockets.total;
  //   for (final entry in days.entries) {
  //     if (entry.key.compareTo(key) <= 0) continue;
  //     value -= entry.value.totalEarned - entry.value.totalSpent;
  //   }
  //   return value;
  // }

  LogbookDay get today => dayFor(todayKey);

  int get todayEntryCount => today.entries.length;

  // Today's reward stays claimable while the day qualifies.
  String? get pendingClaimKey => today.qualifies ? todayKey : null;

  int get streak {
    var cursor = DateTime.now();
    if (!dayFor(logbookDateKey(cursor)).countsForStreak) {
      cursor = cursor.subtract(const Duration(days: 1));
    }

    var count = 0;
    while (dayFor(logbookDateKey(cursor)).countsForStreak) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  int streakOn(String key) {
    var cursor = _parseKey(key);
    var count = 0;
    while (dayFor(logbookDateKey(cursor)).countsForStreak) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  bool isLoggedOn(String key) => dayFor(key).isLogged;

  DateTime _parseKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 2000,
      int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1,
      int.tryParse(parts.length > 2 ? parts[2] : '') ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'days': days.map((key, day) => MapEntry(key, day.toJson())),
      // 'pockets': pockets.toJson(),
      'berries': berries,
      'coinsEarned': coinsEarned,
      'lastClaimKey': lastClaimKey,
      'lastClaimCoins': lastClaimCoins,
      'lastClaimBerries': lastClaimBerries,
    };
  }

  factory LogbookState.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as Map<String, dynamic>? ?? const {};
    return LogbookState(
      days: rawDays.map(
        (key, value) =>
            MapEntry(key, LogbookDay.fromJson(value as Map<String, dynamic>)),
      ),
      // pockets: PocketWallet.fromJson(
      //   json['pockets'] as Map<String, dynamic>? ?? const {},
      // ),
      berries: (json['berries'] as num?)?.toInt() ?? 0,
      coinsEarned: (json['coinsEarned'] as num?)?.toInt() ?? 0,
      lastClaimKey: json['lastClaimKey'] as String?,
      lastClaimCoins: (json['lastClaimCoins'] as num?)?.toInt() ?? 0,
      lastClaimBerries: (json['lastClaimBerries'] as num?)?.toInt() ?? 0,
    );
  }

  LogbookState copyWith({
    Map<String, LogbookDay>? days,
    // PocketWallet? pockets,
    int? berries,
    int? coinsEarned,
    bool? loaded,
    String? lastClaimKey,
    int? lastClaimCoins,
    int? lastClaimBerries,
  }) {
    return LogbookState(
      days: days ?? this.days,
      // pockets: pockets ?? this.pockets,
      berries: berries ?? this.berries,
      coinsEarned: coinsEarned ?? this.coinsEarned,
      loaded: loaded ?? this.loaded,
      lastClaimKey: lastClaimKey ?? this.lastClaimKey,
      lastClaimCoins: lastClaimCoins ?? this.lastClaimCoins,
      lastClaimBerries: lastClaimBerries ?? this.lastClaimBerries,
    );
  }
}
