// Driver entry
import 'package:flutter_driver/driver_extension.dart';
import 'package:thesis_fulgens_mobile/core/router/app_router.dart';
import 'package:thesis_fulgens_mobile/main.dart' as app;

// Driver app
void main() {
  // Real keyboard
  // Route probe
  enableFlutterDriverExtension(
    handler: (message) async {
      if (message == 'getRoute') {
        try {
          return appRouter.state.uri.toString();
        } catch (_) {
          try {
            return appRouter.routerDelegate.currentConfiguration.uri.toString();
          } catch (_) {
            return 'unknown';
          }
        }
      }
      return 'unknown';
    },
    enableTextEntryEmulation: false,
  );
  app.main();
}
