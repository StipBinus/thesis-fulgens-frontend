// Driver entry
import 'package:flutter_driver/driver_extension.dart';
import 'package:thesis_fulgens_mobile/main.dart' as app;

// Driver app
void main() {
  // Real keyboard
  enableFlutterDriverExtension(enableTextEntryEmulation: false);
  app.main();
}
