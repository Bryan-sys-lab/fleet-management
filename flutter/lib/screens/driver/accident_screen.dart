import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/location.dart';
import '../../core/media.dart';
import '../../core/offline/queue.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/form_shell.dart';
import '../../design/components/hold_to_confirm.dart';
import '../../design/components/photo_capture.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/components/status_badge.dart';
import '../../core/offline/queue_store.dart';
import '../../design/tokens.dart';
import '../common.dart';
import 'home_state.dart';

/// Accidents: the Mayday control first (2s hold), then the triaged report.
class AccidentScreen extends ConsumerStatefulWidget {
  const AccidentScreen({super.key});

  @override
  ConsumerState<AccidentScreen> createState() => _AccidentScreenState();
}

class _AccidentScreenState extends ConsumerState<AccidentScreen> {
  final _formKey = GlobalKey<FormShellState>();
  final _statement = TextEditingController();
  final _witness = TextEditingController();
  final _plate = TextEditingController();
  XFile? _front, _rear, _side, _extra;
  bool _busy = false;
  final bool _reduceMotion = false;

  Future<void> _sendMayday() async {
    final strings = context.s;
    final fix = await currentFix();
    if (fix == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.t('mayday.noGps'))));
      return;
    }
    final shift = await ref.read(activeShiftProvider.future);
    try {
      await ref.read(repositoryProvider).mayday({
        'shift_id': shift?['shift_id'],
        'vehicle_id': shift?['vehicle_id'],
        'position': {'latitude': fix.latitude, 'longitude': fix.longitude},
        'mayday_reason': 'Mayday from Accidents',
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.t('mayday.sent'))));
    } catch (e) {
      if (!mounted) return;
      showHelixError(context, e, retry: _sendMayday);
    }
  }

  Future<void> _submit() async {
    final strings = context.s;
    final shift = await ref.read(activeShiftProvider.future);
    if (_statement.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final media = ref.read(mediaProvider);
      final uploads = <StagedUpload>[];
      final pairs = [
        (MediaService.slotAccidentFront, _front),
        (MediaService.slotAccidentRear, _rear),
        (MediaService.slotAccidentSide, _side),
        (MediaService.slotAccidentExtra, _extra),
      ];
      for (final (slotName, file) in pairs) {
        if (file == null) continue;
        final staged = await media.stageCapture(
          await file.readAsBytes(),
          slot: slotName,
          ownerKind: 'ACCIDENT_MEDIA',
          retentionClass: 'ACCIDENT',
        );
        if (staged != null) uploads.add(staged);
      }
      final ops = <QueueOp>[
        QueueOp(
          method: 'POST',
          path: 'accidents',
          body: {
            'shift_id': shift?['shift_id'],
            'vehicle_id': shift?['vehicle_id'],
            'severity': 'MODERATE',
            'driver_statement': _statement.text.trim(),
            if (_witness.text.trim().isNotEmpty) 'witness_name': _witness.text.trim(),
            if (_plate.text.trim().isNotEmpty) 'other_vehicle_plate': _plate.text.trim(),
          },
          produces: 'accident_id',
        ),
      ];
      final result = await ref.read(offQueueProvider).submitStaged(ops);
      if (!mounted) return;
      if (result.allSent) {
        // photos reference the accident via the produces token in a chained write
        if (uploads.isNotEmpty) {
          final chained = QueueOp(
            method: 'POST',
            path: 'accidents/{accident_id}/media',
            body: {'slot': 'OTHER'},
            needs: const ['accident_id'],
          );
          await ref.read(offQueueProvider).submitStaged([chained]);
        }
        _formKey.currentState?.showSent();
      } else {
        _formKey.currentState?.showQueued();
      }
    } on HelixError catch (e) {
      if (!mounted) return;
      _formKey.currentState?.showError(strings.error(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final cameras = ref.watch(camerasProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('nav.accidents'), style: TypeScale.title(AppColors.text))),
      body: Screen(
        child: FormShell(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HoldToConfirm(
                label: strings.t('accident.sendMayday'),
                holdingLabel: strings.t('mayday.holding'),
                onConfirmed: _sendMayday,
                hold: const Duration(seconds: 2),
                reducedMotion: _reduceMotion,
                fillColor: AppColors.statusDanger,
              ),
              const SizedBox(height: AppSpace.s2),
              HelixText(strings.t('accident.maydayHelp'), style: TypeScale.caption(AppColors.textSecondary)),
              const Divider(height: 40, color: AppColors.line),
              HelixText(strings.t('accident.severity'), style: TypeScale.caption(AppColors.textSecondary)),
              const SizedBox(height: AppSpace.s2),
              Wrap(
                spacing: AppSpace.s2,
                children: [
                  HelixChip(label: strings.t('accident.MINOR'), glyph: '—'),
                  HelixChip(label: strings.t('accident.MODERATE'), glyph: '—'),
                  HelixChip(label: strings.t('accident.SEVERE'), glyph: '—'),
                ],
              ),
              const SizedBox(height: AppSpace.s3),
              HelixText('Hint only — the system decides severity', style: TypeScale.caption(AppColors.textTertiary)),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('accident.statement'), controller: _statement, maxLines: 4),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('accident.witness'), controller: _witness),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('accident.plate'), controller: _plate),
              const SizedBox(height: AppSpace.s4),
              PhotoCapture(cameras: cameras, label: context.s.t('accident.slot.FRONT_DAMAGE'), captured: _front, onCaptured: (f) => setState(() => _front = f)),
              const SizedBox(height: AppSpace.s4),
              PhotoCapture(cameras: cameras, label: context.s.t('accident.slot.REAR_DAMAGE'), captured: _rear, onCaptured: (f) => setState(() => _rear = f)),
              const SizedBox(height: AppSpace.s4),
              PhotoCapture(cameras: cameras, label: context.s.t('accident.slot.SIDE_DAMAGE'), captured: _side, onCaptured: (f) => setState(() => _side = f)),
              const SizedBox(height: AppSpace.s4),
              PhotoCapture(cameras: cameras, label: strings.t('accident.addPhoto'), captured: _extra, onCaptured: (f) => setState(() => _extra = f)),
              const SizedBox(height: AppSpace.s5),
              StrandButton(
                label: strings.t('accident.report'),
                shell: Shell.driver,
                onPressed: _busy || _statement.text.trim().isEmpty ? null : _submit,
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
