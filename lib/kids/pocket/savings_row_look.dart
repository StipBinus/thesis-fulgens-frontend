// How one savings entry sits on the white sheet
enum SavingsRowLook { card, bare, airy, ruled }

// Tags shown in the floating picker
const List<String> savingsRowLookNames = <String>[
  'Cards',
  'Bare',
  'Airy',
  'Ruled',
];

// Air between two entries for each look
double savingsEntryGap(SavingsRowLook look) => switch (look) {
  SavingsRowLook.card => 12,
  SavingsRowLook.bare => 10,
  SavingsRowLook.airy => 20,
  SavingsRowLook.ruled => 0,
};
