import 'package:flutter/material.dart';

/// Thin wrapper over the themed ElevatedButton. Exists so call sites read
/// `AppButton.primary(...)` instead of repeating style overrides — if a
/// screen ever needs a one-off variant, add it here once, not per screen.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.icon,
  }) : _variant = _Variant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.icon,
  }) : _variant = _Variant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final IconData? icon;
  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
          );

    final button = _variant == _Variant.primary
        ? ElevatedButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

enum _Variant { primary, secondary }
