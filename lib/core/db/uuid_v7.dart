// UUIDv7: time-ordered id generated on the device, used as the row key.

import 'dart:math';

final Random _random = Random.secure();

String uuidV7() {
  final millis = DateTime.now().millisecondsSinceEpoch;
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

  bytes[0] = (millis >> 40) & 0xFF;
  bytes[1] = (millis >> 32) & 0xFF;
  bytes[2] = (millis >> 24) & 0xFF;
  bytes[3] = (millis >> 16) & 0xFF;
  bytes[4] = (millis >> 8) & 0xFF;
  bytes[5] = millis & 0xFF;

  bytes[6] = (bytes[6] & 0x0F) | 0x70;
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  final hex =
      bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
