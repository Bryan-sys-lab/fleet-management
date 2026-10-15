import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../app/providers.dart';
import '../../data/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/components/status_badge.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Shift detail: verify / flag-with-reason / force-close — all gated.
class ShiftDetailScreen extends ConsumerStatefulWidget {
  const ShiftDetailScreen({super.key, required this.shiftId});

  final String shiftId;

  @override
  ConsumerState<ShiftDetailScreen> createState() => _ShiftDetailScreenState();
}

class _ShiftDetailScreenState extends ConsumerState<ShiftDetailScreen> {
  final _reason = TextEditingController();
  bool _busy = false;

  Future<void> _act(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(_shiftProvider(widget.shiftId));
    } on HelixError catch (e) {
      if (mounted) showHelixError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final repo = ref.watch(repositoryProvider);
    final canVerify = ref.watch(sessionProvider).permissions.contains('shift:verify');
    final canForceClose = ref.watch(sessionProvider).permissions.contains('shift:force_close');
    final async = ref.watch(_shiftProvider(widget.shiftId));
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('shifts.title'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: Screen(
        refresh: () async => ref.invalidate(_shiftProvider(widget.shiftId)),
        child: async.when(
          loading: () => const LoadingBody(),
          error: (e, _) => inlineError(context, e),
          data: (row) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  HelixChip(
                    label: strings.t('shifts.${row['verification_status'] ?? 'PENDING'}'),
                    color: AppColors.statusWarn,
                  ),
                  const SizedBox(width: AppSpace.s2),
                  HelixChip(label: strings.t('shifts.${row['state'] ?? 'OPEN'}'), color: AppColors.statusNeutral),
                ],
              ),
              const SizedBox(height: AppSpace.s4),
              HelixCard(
                child: Column(
                  children: [
                    KeyValueRow(label: strings.t('shifts.clockIn'), value: Fmt.dateTime(DateTime.tryParse(row['clock_in_at']?.toString() ?? ''))),
                    KeyValueRow(label: strings.t('shifts.clockOut'), value: Fmt.dateTime(DateTime.tryParse(row['clock_out_at']?.toString() ?? ''))),
                    KeyValueRow(label: strings.t('shifts.distance'), value: '${row['total_distance_km'] ?? '—'}'),
                    KeyValueRow(label: strings.t('shifts.duration'), value: Fmt.countdown(Duration(seconds: (row['clock_out_at'] != null && row['clock_in_at'] != null) ? DateTime.parse(row['clock_out_at'].toString()).difference(DateTime.parse(row['clock_in_at'].toString())).inSeconds : 0))),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              HelixCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HelixText(strings.t('shifts.workPlan'), style: TypeScale.caption(AppColors.textSecondary)),
                    const SizedBox(height: AppSpace.s2),
                    HelixText(row['planned_notes']?.toString() ?? strings.t('shifts.noPlan'), style: TypeScale.body(AppColors.text)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('shifts.flagReason'), controller: _reason, maxLines: 2),
              const SizedBox(height: AppSpace.s4),
              if (canVerify) ...[
                StrandButton(
                  label: strings.t('admin.verify'),
                  shell: Shell.admin,
                  busy: _busy,
                  onPressed: () => _act(() => repo.verifyShift(widget.shiftId, {'action': 'VERIFY', 'reason': _reason.text.trim().isEmpty ? null : _reason.text.trim()})),
                ),
                const SizedBox(height: AppSpace.s2),
                QuietButton(
                  label: strings.t('admin.flag'),
                  onPressed: () => _act(() => repo.verifyShift(widget.shiftId, {'action': 'FLAG', 'reason': _reason.text.trim()})),
                ),
              ],
              if (canForceClose) ...[
                const SizedBox(height: AppSpace.s2),
                QuietButton(
                  label: strings.t('shifts.forceClose'),
                  onPressed: () => _act(() => repo.forceCloseShift(widget.shiftId, reason: _reason.text.trim().isEmpty ? null : _reason.text.trim())),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final _shiftProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(repositoryProvider).shift(id);
});
