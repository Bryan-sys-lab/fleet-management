import 'package:flutter/material.dart';
import '../tokens.dart';
import 'text.dart';

/// Button family: [StrandButton] primary (active shell strand fill),
/// [QuietButton] secondary, [DangerButton] destructive. Full state set:
/// default / pressed / focused / disabled / busy. No hand-rolled variants.
class StrandButton extends StatefulWidget {
  const StrandButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.shell = Shell.driver,
    this.busy = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Shell shell;
  final bool busy;
  final Widget? icon;

  @override
  State<StrandButton> createState() => _StrandButtonState();
}

class _StrandButtonState extends State<StrandButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final accent = widget.shell.fill;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: AppMotion.durPress,
          curve: AppMotion.easeOut,
          child: AnimatedContainer(
            duration: AppMotion.durPress,
            curve: AppMotion.easeOut,
            height: AppTarget.touchPhone,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
            decoration: BoxDecoration(
              color: !enabled
                  ? AppColors.surfaceSunk
                  : _pressed
                      ? widget.shell.pressed
                      : accent,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            alignment: Alignment.center,
            child: widget.busy
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: widget.shell.onFill),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[widget.icon!, const SizedBox(width: AppSpace.s2)],
                      HelixText(widget.label, style: TypeScale.button(widget.shell.onFill)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class QuietButton extends StatefulWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool busy;

  @override
  State<QuietButton> createState() => _QuietButtonState();
}

class _QuietButtonState extends State<QuietButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: AppMotion.durPress,
          curve: AppMotion.easeOut,
          child: Container(
            height: AppTarget.touchPhone,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s4),
            decoration: BoxDecoration(
              color: _pressed ? AppColors.surfaceSunk : AppColors.surface,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[widget.icon!, const SizedBox(width: AppSpace.s2)],
                HelixText(
                  widget.label,
                  style: TypeScale.button(enabled ? AppColors.text : AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DangerButton extends StatefulWidget {
  const DangerButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  State<DangerButton> createState() => _DangerButtonState();
}

class _DangerButtonState extends State<DangerButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: AppMotion.durPress,
          curve: AppMotion.easeOut,
          child: AnimatedContainer(
            duration: AppMotion.durPress,
            curve: AppMotion.easeOut,
            height: AppTarget.touchPhone,
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.s5),
            decoration: BoxDecoration(
              color: !enabled
                  ? AppColors.surfaceSunk
                  : _pressed
                      ? AppColors.statusDanger
                      : AppColors.statusDanger,
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            alignment: Alignment.center,
            child: widget.busy
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textInverse),
                  )
                : HelixText(widget.label, style: TypeScale.button(AppColors.textInverse)),
          ),
        ),
      ),
    );
  }
}
