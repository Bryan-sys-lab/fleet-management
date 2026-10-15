import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens.dart';
import 'text.dart';

/// Labelled input: label above the field, blur validation, error below,
/// visible required marker, helper text. Sunk well + perceivable outline.
class Field extends StatefulWidget {
  const Field({
    super.key,
    required this.label,
    this.controller,
    this.errorText,
    this.helperText,
    this.required = false,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.enabled = true,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textInputAction,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? helperText;
  final bool required;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextInputAction? textInputAction;

  @override
  State<Field> createState() => _FieldState();
}

class _FieldState extends State<Field> {
  bool _obscure = true;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HelixText(widget.label, style: TypeScale.caption(AppColors.textSecondary)),
            if (widget.required) ...[
              const SizedBox(width: AppSpace.s1),
              HelixText('required', style: TypeScale.caption(AppColors.statusDanger)),
            ],
          ],
        ),
        const SizedBox(height: AppSpace.s2),
        Focus(
          focusNode: _focus,
          child: AnimatedContainer(
            duration: AppMotion.durPress,
            decoration: BoxDecoration(
              color: AppColors.surfaceSunk,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                color: hasError
                    ? AppColors.statusDanger
                    : _focus.hasFocus
                        ? AppColors.accentText
                        : AppColors.line,
                width: _focus.hasFocus || hasError ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    obscureText: widget.obscureText && _obscure,
                    keyboardType: widget.keyboardType,
                    inputFormatters: widget.inputFormatters,
                    enabled: widget.enabled,
                    maxLines: widget.obscureText && _obscure ? 1 : widget.maxLines,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    autofocus: widget.autofocus,
                    textInputAction: widget.textInputAction,
                    style: TypeScale.body(AppColors.text),
                    cursorColor: AppColors.accentText,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSpace.s4,
                        vertical: AppSpace.s4,
                      ),
                      filled: false,
                    ),
                  ),
                ),
                if (widget.obscureText)
                  IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
              ],
            ),
          ),
        ),
        if (widget.helperText != null && !hasError) ...[
          const SizedBox(height: AppSpace.s1),
          HelixText(widget.helperText!, style: TypeScale.caption(AppColors.textSecondary)),
        ],
        if (hasError) ...[
          const SizedBox(height: AppSpace.s1),
          HelixText(widget.errorText!, style: TypeScale.caption(AppColors.statusDanger)),
        ],
      ],
    );
  }
}
