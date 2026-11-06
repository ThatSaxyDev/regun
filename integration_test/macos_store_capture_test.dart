// Run with flutter test integration_test/macos_store_capture_test.dart -d macos.
import 'package:integration_test/integration_test.dart';

import '../tool/store_capture_test.dart' show registerStoreCaptures;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerStoreCaptures(nativeMac: true);
}
