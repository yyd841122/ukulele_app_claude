import 'package:flutter/material.dart';

/// A reusable filled button used across MVP pages.
///
/// T006: intentionally minimal — no theming overrides, no async wrappers.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
