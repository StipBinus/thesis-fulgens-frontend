// No longer used: logbook pockets come from `fetchPockets`, and their icon and
// tint are resolved by `financePocketIcon` / `financePocketTint` in
// ../finance/finance_widgets.dart so the logbook matches the Pockets page.
// Kept for reference.
//
// import 'package:flutter/material.dart';
//
// import 'logbook_models.dart';
//
// // Pocket look
// const Map<PocketSlot, IconData> _pocketIcons = {
//   PocketSlot.cash: Icons.payments_rounded,
//   PocketSlot.snack: Icons.fastfood_rounded,
//   PocketSlot.savings: Icons.savings_rounded,
// };
//
// // Pocket tint
// const Map<PocketSlot, Color> _pocketTints = {
//   PocketSlot.cash: Color(0xFF2E7D32),
//   PocketSlot.snack: Color(0xFF1976D2),
//   PocketSlot.savings: Color(0xFFB07A12),
// };
//
// // Fallback icon
// IconData pocketIcon(PocketSlot slot) =>
//     _pocketIcons[slot] ?? Icons.account_balance_wallet_rounded;
//
// // Fallback tint
// Color pocketColor(PocketSlot slot) =>
//     _pocketTints[slot] ?? const Color(0xFF8E8E93);
