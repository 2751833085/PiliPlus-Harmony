import 'package:flutter/foundation.dart';

abstract final class HarmonyAppearance {
  // Also refreshes settings on covered routes and search results. This also covers
  // options that do not affect ThemeData.
  static final revision = ValueNotifier<int>(0);
  static void changed() => revision.value++;
}
