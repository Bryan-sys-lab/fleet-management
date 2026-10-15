import 'package:flutter/material.dart';
import '../tokens.dart';
import 'text.dart';

enum GaugePosition { empty, quarter, half, threeQuarters, full }

const _gaugeLabels = {
  GaugePosition.empty: 'E',
  GaugePosition.quarter: '¼',
  GaugePosition.half: '½',
  GaugePosition.threeQuarters: '¾',
  GaugePosition.full: 'F',
};

String gaugeApiValue(GaugePosition p) => switch (p) {
      GaugePosition.empty => 'EMPTY',
      GaugePosition.quarter => 'QUARTER',
      GaugePosition.half => 'HALF',
      GaugePosition.threeQuarters => 'THREE_QUARTERS',
      GaugePosition.full => 'FULL',
    };

/// Required fuel-gauge radiogroup — NO default (guard-carried). Glyph + letter.
class GaugePicker extends StatelessWidget {
  const GaugePicker({super.key, required this.value, required this.onChanged});

  final GaugePosition? value;
  final ValueChanged<GaugePosition> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Fuel gauge reading',
      child: Row(
        children: [
          for (final position in GaugePosition.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s1),
                child: _GaugeCell(
                  position: position,
                  selected: value == position,
                  onTap: () => onChanged(position),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GaugeCell extends StatelessWidget {
  const _GaugeCell({required this.position, required this.selected, required this.onTap});

  final GaugePosition position;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: _gaugeLabels[position]!,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.durPress,
          curve: AppMotion.easeOut,
          height: AppTarget.chipPhone,
          decoration: BoxDecoration(
            color: selected ? AppColors.accentQuiet : AppColors.surfaceSunk,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: selected ? AppColors.accentText : AppColors.line),
          ),
          alignment: Alignment.center,
          child: HelixText(
            _gaugeLabels[position]!,
            style: TypeScale.mono(selected ? AppColors.accentText : AppColors.textSecondary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Fuel-gauge fill level (0..1) drawn as a hairline tank — used in detail rows.
class GaugeBar extends StatelessWidget {
  const GaugeBar({super.key, required this.gauge});

  final String? gauge;

  static double? fraction(String? gauge) => switch (gauge?.toUpperCase()) {
        'EMPTY' => 0.05,
        'QUARTER' => 0.28,
        'HALF' => 0.5,
        'THREE_QUARTERS' => 0.74,
        'FULL' => 1.0,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final level = fraction(gauge);
    return Container(
      height: 10,
      width: 72,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunk,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.line),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: level ?? 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.statusOk,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        ),
      ),
    );
  }
}
