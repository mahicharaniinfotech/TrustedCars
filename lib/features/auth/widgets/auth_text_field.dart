import 'package:flutter/material.dart';
import '../../../core/theme/app_dimensions.dart';

/// Labeled input used across auth screens. Visual styling itself comes
/// from InputDecorationTheme in app_theme.dart — this widget just adds
/// the label-above-field layout so every form doesn't repeat it.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.autofillHints,
    this.prefixText,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final String? prefixText;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          autofillHints: autofillHints,
          maxLength: maxLength,
          decoration: InputDecoration(
            prefixText: prefixText,
            counterText: '',
          ),
        ),
      ],
    );
  }
}
