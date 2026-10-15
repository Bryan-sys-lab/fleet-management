import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/media.dart';
import '../../core/offline/queue.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/form_shell.dart';
import '../../design/components/photo_capture.dart';
import '../../design/components/screen.dart';
import '../../design/components/sheet_host.dart';
import '../../design/components/text.dart';
import '../../design/components/skeleton.dart';
import '../../design/tokens.dart';
import '../common.dart';
import 'home_state.dart';

/// Trailer swap: hook an existing trailer / drop (bobtail) / add new + hook photo.
class TrailerSwapScreen extends ConsumerStatefulWidget {
  const TrailerSwapScreen({super.key});

  @override
  ConsumerState<TrailerSwapScreen> createState() => _TrailerSwapScreenState();
}

class _TrailerSwapScreenState extends ConsumerState<TrailerSwapScreen> {
  final _formKey = GlobalKey<FormShellState>();
  final _plate = TextEditingController();
  final _type = TextEditingController();
  final _inspectionId = TextEditingController();
  String? _trailerId;
  String _mode = 'existing'; // existing | bobtail | new
  XFile? _hookPhoto;
  bool _busy = false;

  Future<void> _pick(List<Map<String, dynamic>> trailers) async {
    final picked = await SheetHost.show<String>(
      context: context,
      title: context.s.t('swap.pickExisting'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final trailer in trailers)
            ListTile(
              title: HelixText(trailer['license_plate']?.toString() ?? '', style: TypeScale.body(AppColors.text)),
              subtitle: HelixText(trailer['trailer_type']?.toString() ?? '', style: TypeScale.caption(AppColors.textSecondary)),
              onTap: () => Navigator.of(context).pop(trailer['id'] as String),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _trailerId = picked);
  }

  Future<void> _submit() async {
    final strings = context.s;
    final shift = await ref.read(activeShiftProvider.future);
    if (_hookPhoto == null) return;
    setState(() => _busy = true);
    try {
      final staged = await ref.read(mediaProvider).stageCapture(
        await _hookPhoto!.readAsBytes(),
        slot: MediaService.slotHook,
        ownerKind: 'TRAILER_SWAP',
        retentionClass: 'WORK_PLAN',
      );
      final op = QueueOp(
        method: 'POST',
        path: 'trailer/swap',
        body: {
          if (shift != null) 'shift_id': shift['shift_id'],
          if (shift != null) 'vehicle_id': shift['vehicle_id'],
          if (_mode == 'existing') 'trailer_id': _trailerId,
          if (_mode == 'bobtail') 'trailer_id': null,
          if (_mode == 'new') 'new_trailer_plate': _plate.text.trim(),
          if (_mode == 'new') 'new_trailer_type': _type.text.trim(),
          'hook_media_object_id': staged?.slot ?? 'media://hook',
          'hook_inspection_id': _inspectionId.text.trim(),
        },
        uploads: [?staged],
        produces: 'trailer_assignment_id',
      );
      final result = await ref.read(offQueueProvider).submitStaged([op]);
      if (!mounted) return;
      if (result.allSent) {
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
    final trailersAsync = ref.watch(trailersProvider);
    final cameras = ref.watch(camerasProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('swap.title'), style: TypeScale.title(AppColors.text))),
      body: Screen(
        child: FormShell(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RadioGroup<String>(
                groupValue: _mode,
                onChanged: (value) => setState(() => _mode = value ?? _mode),
                child: Column(
                  children: [
                    _RadioRow(value: 'existing', label: strings.t('swap.pickExisting')),
              if (_mode == 'existing')
                trailersAsync.when(
                  loading: () => Skeleton(height: 40),
                  error: (e, _) => inlineError(context, e),
                  data: (trailers) => trailers.isEmpty
                      ? HelixText(strings.t('swap.noTrailers'), style: TypeScale.caption(AppColors.textSecondary))
                      : OutlinedButton(
                          onPressed: () => _pick(trailers),
                          child: HelixText(_trailerId ?? strings.t('swap.pickExisting'), style: TypeScale.body(AppColors.text)),
                        ),
                ),
                    _RadioRow(value: 'bobtail', label: strings.t('swap.bobtail')),
                    _RadioRow(value: 'new', label: strings.t('swap.addNew')),
                                ],
                ),
              ),
              if (_mode == 'new') ...[
                Field(label: strings.t('swap.plate'), controller: _plate),
                const SizedBox(height: AppSpace.s4),
                Field(label: strings.t('swap.type'), controller: _type),
              ],
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('swap.inspection'), controller: _inspectionId),
              const SizedBox(height: AppSpace.s4),
              PhotoCapture(
                cameras: cameras,
                label: strings.t('swap.hookPhoto'),
                captured: _hookPhoto,
                onCaptured: (f) => setState(() => _hookPhoto = f),
              ),
              const SizedBox(height: AppSpace.s5),
              StrandButton(
                label: strings.t('actions.submit'),
                shell: Shell.driver,
                onPressed: _busy ? null : _submit,
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Radio row whose group state comes from the `RadioGroup` ancestor (Flutter
/// 3.47 radio API). Tapping anywhere on the row selects it.
class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      activeColor: AppColors.accentText,
      contentPadding: EdgeInsets.zero,
      title: HelixText(label, style: TypeScale.body(AppColors.text)),
    );
  }
}
