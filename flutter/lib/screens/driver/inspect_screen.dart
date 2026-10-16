import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/extensions.dart';
import '../../core/offline/queue.dart';
import '../../core/offline/queue_store.dart';
import '../../design/components/buttons.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/form_shell.dart';
import '../../design/components/photo_capture.dart';
import '../../design/components/screen.dart';
import '../../design/components/sheet_host.dart';
import '../../design/components/skeleton.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';
import 'home_state.dart';

/// Template-driven DVIR: PASS/FAIL/NA per item (numeric within server bounds),
/// FAIL needs note + photo, defects-reviewed toggle, signature.
class InspectScreen extends ConsumerStatefulWidget {
  const InspectScreen({super.key});

  @override
  ConsumerState<InspectScreen> createState() => _InspectScreenState();
}

class _InspectScreenState extends ConsumerState<InspectScreen> {
  final _formKey = GlobalKey<FormShellState>();
  final _signature = TextEditingController();
  String? _templateId;
  final Map<String, String> _results = {}; // template_item_id -> PASS/FAIL/NOT_APPLICABLE
  final Map<String, TextEditingController> _numeric = {};
  final Map<String, TextEditingController> _notes = {};
  final Map<String, XFile> _photos = {};
  bool _defectsReviewed = false;
  bool _busy = false;

  @override
  void dispose() {
    _signature.dispose();
    for (final c in _numeric.values) {
      c.dispose();
    }
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTemplate(List<Map<String, dynamic>> templates) async {
    final picked = await SheetHost.show<String>(
      context: context,
      title: context.s.t('forms.useTemplate'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final template in templates)
            ListTile(
              title: HelixText(template['label']?.toString() ?? '', style: TypeScale.body(AppColors.text)),
              onTap: () => Navigator.of(context).pop(template['template_id'] as String),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _templateId = picked);
  }

  List<String> _missing(Map<String, dynamic> template) {
    final missing = <String>[];
    final items = (template['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final item in items) {
      final id = item['template_item_id'] as String;
      final result = _results[id];
      if (item['is_required'] == true && result == null) missing.add(item['label_en']?.toString() ?? id);
      if (result == 'FAIL') {
        final note = _notes[id]?.text.trim() ?? '';
        if (note.isEmpty || _photos[id] == null) missing.add('${item['label_en']} photo+note');
        final numeric = item['input_type'] == 'NUMERIC';
        if (numeric) {
          final value = item['min_value'] != null && item['max_value'] != null;
          final parsed = double.tryParse(_numeric[id]?.text ?? '');
          if (value && (parsed == null || parsed < (item['min_value'] as num) || parsed > (item['max_value'] as num))) {
            missing.add('${item['label_en']} range');
          }
        }
      }
    }
    if (!_defectsReviewed) missing.add('Defects reviewed');
    if (_signature.text.trim().isEmpty) missing.add('Signature');
    return missing;
  }

  Future<void> _submit(Map<String, dynamic> template) async {
    final strings = context.s;
    final shift = await ref.read(activeShiftProvider.future);
    if (shift == null) return;
    setState(() => _busy = true);
    try {
      final media = ref.read(mediaProvider);
      final items = <Map<String, dynamic>>[];
      final uploads = <StagedUpload>[];
      final templateItems = (template['items'] as List).cast<Map<String, dynamic>>();
      for (final item in templateItems) {
        final id = item['template_item_id'] as String;
        var result = _results[id];
        final note = _notes[id]?.text.trim();
        var photoId = 'media://defect';
        if (result == 'FAIL') {
          final staged = await media.stageCapture(
            await _photos[id]!.readAsBytes(),
            slot: 'media://defect_$id',
            ownerKind: 'INSPECTION_ITEM',
            retentionClass: 'INSPECTION',
          );
          if (staged != null) {
            uploads.add(staged);
            photoId = staged.slot;
          }
        }
        if (item['input_type'] == 'NUMERIC' && (_numeric[id]?.text.isNotEmpty ?? false)) {
          result ??= 'PASS';
        }
        items.add({
          'template_item_id': id,
          'result': result,
          if (item['input_type'] == 'NUMERIC' && (_numeric[id]?.text.isNotEmpty ?? false))
            'numeric_value': double.tryParse(_numeric[id]!.text),
          if (note != null && note.isNotEmpty) 'notes': note,
          if (result == 'FAIL') 'photo_media_object_id': photoId,
        });
      }
      final op = QueueOp(
        method: 'POST',
        path: 'inspections',
        body: {
          'shift_id': shift['shift_id'],
          'template_id': _templateId,
          'subject': template['subject'] ?? 'VEHICLE',
          'previous_defects_reviewed': true,
          'signature_name': _signature.text.trim(),
          'items': items,
        },
        uploads: uploads,
        produces: 'inspection_id',
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
    final templatesAsync = ref.watch(templatesProvider);
    final template = templatesAsync.maybeWhen(
      data: (list) => list.where((e) => e['template_id'] == _templateId).firstMatchOrNull(),
      orElse: () => null,
    );
    final cameras = ref.watch(camerasProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('forms.titleInspect'), style: TypeScale.title(AppColors.text))),
      body: Screen(
        child: FormShell(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              templatesAsync.when(
                loading: () => Skeleton(height: 56),
                error: (e, _) => inlineError(context, e),
                data: (templates) => OutlinedButton.icon(
                  icon: Icon(Icons.checklist, color: AppColors.textSecondary),
                  label: HelixText(
                    template?['label']?.toString() ?? strings.t('forms.template'),
                    style: TypeScale.body(AppColors.text),
                  ),
                  onPressed: () => _pickTemplate(templates),
                ),
              ),
              if (template != null) ...[
                const SizedBox(height: AppSpace.s4),
                for (final item in (template['items'] as List).cast<Map<String, dynamic>>())
                  _ItemCard(
                    item: item,
                    result: _results[item['template_item_id'] as String],
                    numericController: _numeric.putIfAbsent(item['template_item_id'] as String, TextEditingController.new),
                    noteController: _notes.putIfAbsent(item['template_item_id'] as String, TextEditingController.new),
                    photo: _photos[item['template_item_id'] as String],
                    onResult: (r) => setState(() => _results[item['template_item_id'] as String] = r),
                    onPhoto: (file) => setState(() => _photos[item['template_item_id'] as String] = file),
                    cameras: cameras,
                  ),
                const SizedBox(height: AppSpace.s4),
                CheckboxListTile(
                  value: _defectsReviewed,
                  activeColor: AppColors.accentText,
                  contentPadding: EdgeInsets.zero,
                  title: HelixText(strings.t('forms.defectsReviewed'), style: TypeScale.body(AppColors.text)),
                  onChanged: (v) => setState(() => _defectsReviewed = v == true),
                ),
                const SizedBox(height: AppSpace.s4),
                Field(label: strings.t('forms.signature'), controller: _signature),
                if (_missing(template).isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s3),
                  HelixText(
                    strings.t('forms.missing', {'items': _missing(template).join(', ')}),
                    style: TypeScale.caption(AppColors.statusWarn),
                  ),
                ],
                const SizedBox(height: AppSpace.s5),
                StrandButton(
                  label: strings.t('actions.submit'),
                  shell: Shell.driver,
                  onPressed: (_missing(template).isNotEmpty || _busy) ? null : () => _submit(template),
                  busy: _busy,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({
    required this.item,
    required this.result,
    required this.numericController,
    required this.noteController,
    required this.photo,
    required this.onResult,
    required this.onPhoto,
    this.cameras = const [],
  });

  final Map<String, dynamic> item;
  final String? result;
  final TextEditingController numericController;
  final TextEditingController noteController;
  final XFile? photo;
  final ValueChanged<String> onResult;
  final ValueChanged<XFile> onPhoto;
  final List<CameraDescription> cameras;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    final numeric = item['input_type'] == 'NUMERIC';
    return HelixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HelixText(item['label_en']?.toString() ?? '', style: TypeScale.bodyStrong(AppColors.text)),
          if (item['severity'] == 'BLOCKER') ...[
            const SizedBox(height: AppSpace.s1),
            HelixText(strings.t('detail.blockerItem'), style: TypeScale.caption(AppColors.statusDanger)),
          ],
          const SizedBox(height: AppSpace.s3),
          Row(
            children: [
              ChoiceChip(
                label: HelixText(strings.t('forms.pass'), style: TypeScale.caption(
                  result == 'PASS' ? AppColors.text : AppColors.textSecondary,
                )),
                selected: result == 'PASS',
                selectedColor: AppColors.accentQuiet,
                onSelected: (_) => onResult('PASS'),
              ),
              const SizedBox(width: AppSpace.s2),
              ChoiceChip(
                label: HelixText(strings.t('forms.fail'), style: TypeScale.caption(
                  result == 'FAIL' ? AppColors.statusDanger : AppColors.textSecondary,
                )),
                selected: result == 'FAIL',
                selectedColor: AppColors.statusDanger.withValues(alpha: 0.10),
                onSelected: (_) => onResult('FAIL'),
              ),
              const SizedBox(width: AppSpace.s2),
              ChoiceChip(
                label: HelixText(strings.t('forms.na'), style: TypeScale.caption(AppColors.textSecondary)),
                selected: result == 'NOT_APPLICABLE',
                onSelected: (_) => onResult('NOT_APPLICABLE'),
              ),
            ],
          ),
          if (numeric) ...[
            const SizedBox(height: AppSpace.s3),
            Field(
              label: '${item['unit'] ?? ''} ${item['min_value'] ?? ''}–${item['max_value'] ?? ''}',
              controller: numericController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          if (result == 'FAIL') ...[
            const SizedBox(height: AppSpace.s3),
            Field(label: strings.t('forms.notes'), controller: noteController, maxLines: 2),
            const SizedBox(height: AppSpace.s3),
            PhotoCapture(
              cameras: cameras,
              label: strings.t('forms.itemPhoto'),
              captured: photo,
              onCaptured: onPhoto,
            ),
          ],
        ],
      ),
    );
  }
}

