import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Harmony proportions, with a full 52×48 hit area and keyboard/semantics support.
class HarmonySwitch extends StatefulWidget {
  const HarmonySwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  State<HarmonySwitch> createState() => _HarmonySwitchState();
}

class _HarmonySwitchState extends State<HarmonySwitch> {
  bool _focused = false;
  double _drag = 0;

  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onChanged != null;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (value) => setState(() => _focused = value),
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _toggle();
              return null;
            },
          ),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? _toggle : null,
          onHorizontalDragStart: enabled ? (_) => _drag = 0 : null,
          onHorizontalDragUpdate: enabled ? (d) => _drag += d.delta.dx : null,
          onHorizontalDragEnd: enabled
              ? (_) {
                  if (_drag.abs() > 8) {
                    final next = rtl ? _drag < 0 : _drag > 0;
                    if (next != widget.value) widget.onChanged!(next);
                  }
                }
              : null,
          child: SizedBox(
            width: 52,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                width: 52,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: (widget.value ? scheme.primary : scheme.outlineVariant)
                      .withValues(alpha: enabled ? 1 : 0.4),
                  boxShadow: _focused
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.3),
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: AnimatedAlign(
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  alignment: widget.value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: const SizedBox.square(
                    dimension: 26,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
