import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/container.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/media.dart';
import '../../core/offline/queue.dart';
import '../../core/offline/queue_store.dart';
import '../../design/components/buttons.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/form_shell.dart';
import '../../design/components/gauge_picker.dart';
import '../../design/components/photo_capture.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/components/skeleton.dart';
import '../../design/tokens.dart';
import '../common.dart';
import 'home_state.dart';

/// Clock in: assignment (server-decided) → odometer (guarded) → gauge
/// (required) → photo → optional plan → honest location toggle → submit.
class ClockInScreen extends ConsumerStatefulWidget {
  const ClockInScreen({super.key});

  @override
  ConsumerState<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends ConsumerState<ClockInScreen> {
  final _odometer = TextEditingController();
  final _notes = TextEditingController();
  final _formKey = GlobalKey<FormShellState>();
  GaugePosition? _gauge;
  XFile? _photo;
  bool _shareLocation = false;
  bool _busy = false;
  String? _disclaimer;


  Future<void> _submit() async {
    final strings = context.s;
    final repo = ref.read(repositoryProvider);
    final container = ref.read(containerProvider);
    final assignment = await repo.myAssignment();
    final shiftVehicle = assignment?['vehicle_id'] as String?;
    final km = int.tryParse(_odometer.text.trim());

    if (km == null || _gauge == null || _photo == null || shiftVehicle == null) return;

    setState(() => _busy = true);
    try {
      if (_shareLocation) {
        await container.phoneTracker.start(); // start BEFORE the write so the flag is honest
      }
      final staged = await ref.read(mediaProvider).stageCapture(
        await _photo!.readAsBytes(),
        slot: MediaService.slotClockIn,
        ownerKind: 'WORK_LOG_PHOTO',
        retentionClass: 'WORK_PLAN',
      );
      if (staged == null) {
        setState(() => _busy = false);
        return;
      }
      final op = QueueOp(
        method: 'POST',
        path: 'shifts/clock-in',
        body: {
          'assignment_id': assignment!['id'],
          'start_odometer_km': km,
          'start_fuel_gauge': gaugeApiValue(_gauge!),
          'start_media_object_id': staged.slot,
          'phone_gps_fallback_enabled': _shareLocation,
          'consent_version': '2026.1',
          if (_notes.text.trim().isNotEmpty) 'planned_notes': _notes.text.trim(),
        },
        uploads: [staged],
        produces: 'shift_id',
      );
      final result = await ref.read(offQueueProvider).submitStaged([op]);
      if (!mounted) return;
      if (result.allSent) {
        // the server returns its disclaimer beside a successful clock-in
        setState(() {
          _disclaimer = result.firstResponse?['disclaimer'] as String?;
          _busy = false;
        });
        _formKey.currentState?.showSent();
      } else {
        _formKey.currentState?.showQueued();
        setState(() => _busy = false);
      }
    } on HelixError catch (e) {
      if (!mounted) return;
      _formKey.currentState?.showError(strings.error(e.code));
      setState(() => _busy = false);
    }
  }

  List<String> _missing() {
    final missing = <String>[];
    if (int.tryParse(_odometer.text.trim()) == null) missing.add('Odometer');
    if (_gauge == null) missing.add('Fuel gauge');
    if (_photo == null) missing.add('Photo');
    return missing;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final missing = _missing();
    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('shift.clockIn'), style: TypeScale.title(AppColors.text))),
      body: Screen(
        child: FormShell(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ref.watch(assignmentProvider).when(
                loading: () => Skeleton(height: 56),
                error: (e, _) => inlineError(context, e),
                data: (assignment) => HelixCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HelixText(strings.t('shift.assignment'), style: TypeScale.caption(AppColors.textSecondary)),
                      const SizedBox(height: AppSpace.s1),
                      HelixText(
                        assignment?['vehicle_label']?.toString() ??
                            assignment?['plate']?.toString() ??
                            '—',
                        style: TypeScale.lead(AppColors.text),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s4),
              Field(
                label: strings.t('shift.odometer'),
                controller: _odometer,
                keyboardType: TextInputType.number,
                helperText: strings.t('forms.lastReading', {'km': '—'}),
              ),
              const SizedBox(height: AppSpace.s4),
              HelixText(strings.t('gauge.label'), style: TypeScale.caption(AppColors.textSecondary)),
              const SizedBox(height: AppSpace.s2),
              GaugePicker(
                value: _gauge,
                onChanged: (v) => setState(() => _gauge = v),
              ),
              const SizedBox(height: AppSpace.s4),
              PhotoCapture(
                cameras: ref.watch(camerasProvider).valueOrNull ?? const [],
                label: strings.t('shift.photo'),
                captured: _photo,
                onCaptured: (file) => setState(() => _photo = file),
              ),
              const SizedBox(height: AppSpace.s4),
              Field(
                label: strings.t('shift.workPlan'),
                controller: _notes,
                maxLines: 3,
              ),
              const SizedBox(height: AppSpace.s4),
              SwitchListTile(
                value: _shareLocation,
                activeThumbColor: AppColors.accentText,
                title: HelixText(strings.t('shift.phoneFallback'), style: TypeScale.body(AppColors.text)),
                subtitle: HelixText(strings.t('shift.phoneFallbackHelp'), style: TypeScale.caption(AppColors.textSecondary)),
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _shareLocation = v),
              ),
              if (missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.s3),
                  child: HelixText(
                    strings.t('forms.missing', {'items': missing.join(', ')}),
                    style: TypeScale.caption(AppColors.statusWarn),
                  ),
                ),
              if (_disclaimer != null) ...[
                const SizedBox(height: AppSpace.s4),
                HelixCard(
                  child: HelixText(_disclaimer!, style: TypeScale.body(AppColors.text)),
                ),
              ],
              const SizedBox(height: AppSpace.s5),
              StrandButton(
                label: strings.t('actions.submit'),
                shell: Shell.driver,
                onPressed: (missing.isNotEmpty || _busy) ? null : _submit,
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
