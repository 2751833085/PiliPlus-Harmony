import 'dart:async';
import 'package:flutter/widgets.dart';

/// Avoid a loading flash during a cache hit / decoder handoff. A real stall
/// still exposes the existing retry/loading UI after a short grace period.
class ShortLoadingGrace extends StatefulWidget {
  const ShortLoadingGrace({super.key, required this.child});
  final Widget child;
  @override
  State<ShortLoadingGrace> createState() => _ShortLoadingGraceState();
}

class _ShortLoadingGraceState extends State<ShortLoadingGrace> {
  bool _visible = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : const SizedBox.shrink();
}
