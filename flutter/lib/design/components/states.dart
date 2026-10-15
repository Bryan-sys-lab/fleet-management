import 'package:flutter/material.dart';
import '../tokens.dart';
import 'buttons.dart';
import 'text.dart';

/// Error state: the catalogue message and EXACTLY ONE action button.
/// RATE_LIMITED shows a countdown before the retry unlocks.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.detail,
    this.waitSeconds,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? detail;
  final int? waitSeconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HelixText(message, style: TypeScale.body(AppColors.text), textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: AppSpace.s2),
            HelixText(detail!, style: TypeScale.caption(AppColors.textSecondary), textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpace.s4),
            if (waitSeconds != null && waitSeconds! > 0)
              QuietButton(label: '$actionLabel (${waitSeconds}s)', onPressed: null)
            else
              QuietButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

/// Empty state: what this view is for + the one next action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HelixText(message, style: TypeScale.body(AppColors.textSecondary), textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpace.s4),
            QuietButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
