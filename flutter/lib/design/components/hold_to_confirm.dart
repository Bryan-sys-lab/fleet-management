import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens.dart';
import 'text.dart';

/// Hold-to-confirm gesture engine (Mayday, destructive confirms). The fill
/// overlay is the commitment; reduced-motion and switch-access users get the
/// same result via a labelled two-step confirm.
class HoldToConfirm extends StatefulWidget {
  const HoldToConfirm({
    super.key,
    required this.label,
    required this.onConfirmed,
    required this.hold,
    this.holdingLabel,
    this.reducedMotion = false,
    this.fillColor = AppColors.statusDanger,
    this.textColor = AppColors.textInverse,
    this.height = AppTarget.touchPhone + 8,
  });

  final String label;
  final VoidCallback onConfirmed;
  final Duration hold;
  final String? holdingLabel;
  final bool reducedMotion;
  final Color fillColor;
  final Color textColor;
  final double height;

  @override
  State<HoldToConfirm> createState() => _HoldToConfirmState();
}

class _HoldToConfirmState extends State<HoldToConfirm> {
  Timer? _timer;
  double _progress = 0;
  bool _holding = false;
  bool _armed = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (_holding) return;
    setState(() {
      _holding = true;
      _progress = 0;
    });
    final steps = 50;
    final stepDuration = Duration(milliseconds: widget.hold.inMilliseconds ~/ steps);
    _timer = Timer.periodic(stepDuration, (timer) {
      setState(() => _progress += 1 / steps);
      if (_progress >= 1) {
        timer.cancel();
        _commit();
      }
    });
  }

  void _cancel() {
    _timer?.cancel();
    if (!_holding) return;
    setState(() {
      _holding = false;
      _progress = 0;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _commit() async {
    _timer?.cancel();
    setState(() {
      _holding = false;
      _progress = 1;
    });
    await HapticFeedback.vibrate();
    widget.onConfirmed();
    if (mounted) setState(() => _progress = 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reducedMotion) {
      return _buildTwoStep();
    }
    return Semantics(
      button: true,
      label: widget.label,
      hint: 'Hold for ${widget.hold.inSeconds} seconds',
      child: GestureDetector(
        onLongPressStart: (_) => _start(),
        onLongPressEnd: (_) => _cancel(),
        onLongPressCancel: _cancel,
        onTap: _holding ? _cancel : null,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surfaceSunk,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: widget.fillColor),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.fillColor,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                ),
              ),
              Center(
                child: HelixText(
                  _holding ? (widget.holdingLabel ?? 'Keep holding…') : widget.label,
                  style: TypeScale.button(_progress > 0.5 ? widget.textColor : widget.fillColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Non-gesture fallback: tap arms, second tap confirms.
  Widget _buildTwoStep() {
    return Semantics(
      button: true,
      label: _armed ? 'Tap again to confirm' : widget.label,
      child: GestureDetector(
        onTap: () {
          if (_armed) {
            setState(() => _armed = false);
            widget.onConfirmed();
          } else {
            setState(() => _armed = true);
          }
        },
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: _armed ? widget.fillColor : AppColors.surfaceSunk,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: widget.fillColor),
          ),
          alignment: Alignment.center,
          child: HelixText(
            _armed ? 'Tap again to confirm' : widget.label,
            style: TypeScale.button(_armed ? widget.textColor : widget.fillColor),
          ),
        ),
      ),
    );
  }
}
