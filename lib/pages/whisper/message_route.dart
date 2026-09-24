import 'package:PiliPlus/harmony_adapt/harmony_theme.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

Future<T?>? openMessagePage<T>(
  String name,
  Widget Function() page, {
  Object? arguments,
}) {
  if (!Pref.harmonyUI) return Get.toNamed<T>(name, arguments: arguments);
  return Get.key.currentState!.push<T>(
    HarmonyMessageRoute<T>(
      page: page,
      settings: RouteSettings(name: name, arguments: arguments),
    ),
  );
}

/// A short, fixed-distance entrance avoids sweeping an entire unfolded screen.
class HarmonyMessageRoute<T> extends GetPageRoute<T> {
  HarmonyMessageRoute({required super.page, super.settings});
  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const HarmonyPageTransitionsBuilder().buildTransitions(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
