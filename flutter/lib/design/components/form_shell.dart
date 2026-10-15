import 'package:flutter/material.dart';
import '../tokens.dart';
import 'text.dart';

/// Wraps every tab form. On success the body remounts (remount key) so a form
/// cannot double-submit, and a queued/sent banner reports the outcome —
/// including anomalies flagged beside a SUCCESSFUL save.
class FormShell extends StatefulWidget {
  const FormShell({super.key, required this.child});

  final Widget child;

  @override
  State<FormShell> createState() => FormShellState();
}

class FormShellState extends State<FormShell> {
  int _remountKey = 0;
  String? _banner;
  bool _isError = false;
  List<String> _signals = const [];

  void showQueued({List<String> signals = const []}) {
    setState(() {
      _banner = 'Saved. It will send when you are back online.';
      _isError = false;
      _signals = signals;
      _remountKey++;
    });
  }

  void showSent({List<String> signals = const []}) {
    setState(() {
      _banner = 'Sent.';
      _isError = false;
      _signals = signals;
      _remountKey++;
    });
  }

  void showError(String message) {
    setState(() {
      _banner = message;
      _isError = true;
      _signals = const [];
    });
  }

  void clearBanner() {
    setState(() {
      _banner = null;
      _isError = false;
      _signals = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_banner != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s4),
            child: AnimatedOpacity(
              opacity: 1,
              duration: AppMotion.durFade,
              curve: AppMotion.easeOut,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.s4),
                decoration: BoxDecoration(
                  color: _isError ? AppColors.surfaceSunk : AppColors.accentQuiet,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: _isError ? AppColors.statusDanger : AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HelixText(
                      _banner!,
                      style: TypeScale.bodyStrong(_isError ? AppColors.statusDanger : AppColors.text),
                    ),
                    for (final signal in _signals)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpace.s1),
                        child: HelixText(signal, style: TypeScale.caption(AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        KeyedSubtree(
          key: ValueKey(_remountKey),
          child: widget.child,
        ),
      ],
    );
  }
}
