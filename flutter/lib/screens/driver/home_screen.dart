import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../core/location.dart';
import '../../design/components/buttons.dart';
import '../../design/components/card.dart';
import '../../design/components/chips.dart';
import '../../design/components/hold_to_confirm.dart';
import '../../design/components/privacy_shield.dart';
import '../../design/components/screen.dart';
import '../../app/container.dart';
import '../../design/components/skeleton.dart';
import '../../design/components/status_badge.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';
import 'home_state.dart';

/// Driver Home: "where do I stand". Shift state → Mayday → clock out → rest
/// banner → quick links. The single largest control is never a submit button.
class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  Timer? _ticker;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _sendMayday() async {
    final repo = ref.read(repositoryProvider);
    final container = ref.read(containerProvider);
    final strings = context.s;
    final fix = await currentFix();
    if (fix == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('mayday.noGps'))),
      );
      return;
    }
    final shift = await ref.read(activeShiftProvider.future);
    try {
      await repo.mayday({
        'shift_id': shift?['shift_id'],
        'vehicle_id': shift?['vehicle_id'] ?? (await repo.myAssignment())?['vehicle_id'],
        'position': {'latitude': fix.latitude, 'longitude': fix.longitude},
        'mayday_reason': 'Mayday from Home',
      });
      container.phoneTracker.flushOnStop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.t('mayday.sent'))),
      );
    } catch (e) {
      if (!mounted) return;
      showHelixError(context, e, retry: _sendMayday);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final shiftAsync = ref.watch(activeShiftProvider);
    final onboardingAsync = ref.watch(onboardingProvider);
    final outboxAsync = ref.watch(outboxCountProvider);

    return PrivacyShield(
      child: Screen(
        refresh: () async {
          ref.invalidate(activeShiftProvider);
          ref.invalidate(onboardingProvider);
          ref.invalidate(outboxCountProvider);
        },
        child: Column
          (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpace.s2),
            HelixText(
              onboardingAsync.whenOrNull(data: (v) => v?['full_name'] as String?) ?? strings.t('nav.home'),
              style: TypeScale.display(AppColors.text),
            ),
            const SizedBox(height: AppSpace.s5),

            // ── Mayday: the one emergency control ──
            HoldToConfirm(
              label: strings.t('mayday.hold'),
              holdingLabel: strings.t('mayday.holding'),
              onConfirmed: _sendMayday,
              hold: const Duration(seconds: 2),
              reducedMotion: _reduceMotion,
              fillColor: AppColors.statusDanger,
            ),
            const SizedBox(height: AppSpace.s2),
            HelixText(strings.t('mayday.hint'), style: TypeScale.caption(AppColors.textSecondary)),
            const SizedBox(height: AppSpace.s5),

            // ── shift state ──
            shiftAsync.when(
              loading: () => const HelixCard(child: Skeleton(height: 72)),
              error: (e, _) => HelixCard(child: inlineError(context, e, retry: () => ref.invalidate(activeShiftProvider))),
              data: (shift) => _ShiftCard(
                shift: shift,
                onClockOut: () => context.push('/driver/clock-out'),
                onClockIn: () => context.push('/driver/clock-in'),
              ),
            ),

            // ── rest banner ──
            ref.watch(hosRestProvider).maybeWhen(
                  data: (rest) => rest == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s4),
                          child: HelixCard(
                            child: Row(
                              children: [
                                const Icon(Icons.schedule, color: AppColors.statusAmber),
                                const SizedBox(width: AppSpace.s3),
                                Expanded(
                                  child: HelixText(
                                    strings.t('shift.restUntil', {'time': Fmt.time(rest)}),
                                    style: TypeScale.body(AppColors.text),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),

            const SizedBox(height: AppSpace.s5),
            // ── quick links ──
            Row(
              children: [
                Expanded(
                  child: QuietButton(
                    label: strings.t('swap.title'),
                    icon: const Icon(Icons.local_shipping_outlined, size: 20, color: AppColors.textSecondary),
                    onPressed: () => context.push('/driver/trailer-swap'),
                  ),
                ),
                const SizedBox(width: AppSpace.s3),
                Expanded(
                  child: QuietButton(
                    label: strings.t('vehicle.title'),
                    icon: const Icon(Icons.directions_bus_outlined, size: 20, color: AppColors.textSecondary),
                    onPressed: () => context.push('/driver/my-vehicle'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            outboxAsync.maybeWhen(
              data: (count) => count > 0
                  ? GestureDetector(
                      onTap: () => context.push('/driver/outbox'),
                      child: Row(
                        children: [
                          PendingChip(label: '${strings.t('outbox.title')} · $count'),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift, required this.onClockIn, required this.onClockOut});

  final Map<String, dynamic>? shift;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    if (shift == null) {
      return HelixCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HelixChip(label: strings.t('shift.noShift'), color: AppColors.statusNeutral, glyph: '○'),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            HelixText(strings.t('shift.noAssignmentHint'), style: TypeScale.body(AppColors.textSecondary)),
            const SizedBox(height: AppSpace.s4),
            StrandButton(label: strings.t('shift.clockIn'), shell: Shell.driver, onPressed: onClockIn),
          ],
        ),
      );
    }
    final clockInAt = DateTime.tryParse(shift!['clock_in_at']?.toString() ?? '')?.toUtc();
    final duty = clockInAt == null ? '' : Fmt.countdown(DateTime.now().toUtc().difference(clockInAt));
    return HelixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HelixChip(label: strings.t('shift.clockedIn'), color: AppColors.statusOk, glyph: '►'),
              const Spacer(),
              HelixText(duty, style: TypeScale.mono(AppColors.text)),
            ],
          ),
          const SizedBox(height: AppSpace.s3),
          KeyValueRow(
            label: strings.t('shift.assignment'),
            value: shift!['vehicle_label']?.toString() ?? '—',
            mono: false,
          ),
          const SizedBox(height: AppSpace.s2),
          StrandButton(label: strings.t('shift.clockOut'), shell: Shell.driver, onPressed: onClockOut),
        ],
      ),
    );
  }
}
