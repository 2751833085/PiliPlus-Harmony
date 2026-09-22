import 'package:path/path.dart' as path;

/// Compile-time-only profile for device QA. Production builds use the original
/// directories and never read this profile's accounts, preferences or downloads.
abstract final class QaProfile {
  static const guest = bool.fromEnvironment('HARMONY_QA_GUEST');
  static String directory(String original, {bool isolated = guest}) =>
      isolated ? path.join(original, 'qa-guest-v1') : original;
}
