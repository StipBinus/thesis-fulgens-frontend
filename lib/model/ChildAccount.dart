class ChildAccount {
  const ChildAccount({
    required this.childId,
    required this.name,
    required this.userCurrency,
    required this.parentCurrency,
    required this.userBalance,
  });

  final String childId;
  final String name;
  final int userCurrency; // game balance
  final int parentCurrency;
  final int userBalance; // current balance

  factory ChildAccount.fromJson(Map<String, dynamic> json) => ChildAccount(
    childId: json['childId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    userCurrency: _intValue(json['userCurrency']),
    parentCurrency: _intValue(json['parentCurrency']),
    userBalance: _intValue(json['userBalance']),
  );
}

int _intValue(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
