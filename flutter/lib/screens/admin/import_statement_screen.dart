import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';
import '../../app/providers.dart';
import '../../data/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Fuel statement import: presigned media upload of a CSV, then
/// POST /reconciliation/statements with the provider, period and mapping.
class ImportStatementScreen extends ConsumerStatefulWidget {
  const ImportStatementScreen({super.key});

  @override
  ConsumerState<ImportStatementScreen> createState() => _ImportStatementScreenState();
}

class _ImportStatementScreenState extends ConsumerState<ImportStatementScreen> {
  final _provider = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _date = TextEditingController(text: 'Date');
  final _amount = TextEditingController(text: 'Amount');
  final _card = TextEditingController(text: 'Card');
  final _litres = TextEditingController(text: 'Litres');
  final _station = TextEditingController(text: 'Station');
  String? _mediaObjectId;
  bool _busy = false;

  @override
  void dispose() {
    _provider.dispose();
    _start.dispose();
    _end.dispose();
    _date.dispose();
    _amount.dispose();
    _card.dispose();
    _litres.dispose();
    _station.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final strings = context.s;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).importStatement({
        'provider': _provider.text.trim(),
        'period_start': _start.text.trim(),
        'period_end': _end.text.trim(),
        'media_object_id': _mediaObjectId ?? '',
        'column_mapping': {
          'date': _date.text.trim(),
          'amount': _amount.text.trim(),
          'card': _card.text.trim(),
          'litres': _litres.text.trim(),
          'station': _station.text.trim(),
        },
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.t('importer.done'))));
      Navigator.of(context).pop();
    } on HelixError catch (e) {
      if (!mounted) return;
      showHelixError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('importer.title'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: Screen(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HelixCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HelixText(strings.t('importer.pick'), style: TypeScale.body(AppColors.text)),
                  const SizedBox(height: AppSpace.s2),
                  OutlinedButton.icon(
                    icon: Icon(Icons.attach_file, color: AppColors.adminAccent),
                    label: HelixText(_mediaObjectId == null ? strings.t('importer.pick') : 'Uploaded', style: TypeScale.body(AppColors.text)),
                    onPressed: () async {
                      // The CSV goes through the same presign path as photos:
                      // media/upload-url (retention_class STATEMENT_IMPORT) → PUT.
                      final result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['csv'],
                        withData: true,
                      );
                      final picked = result?.files.firstOrNull;
                      if (picked == null || picked.bytes == null) return;
                      final media = ref.read(mediaProvider);
                      final staged = await media.stageCapture(
                        picked.bytes!,
                        slot: 'media://statement',
                        ownerKind: 'FUEL_PURCHASE',
                        retentionClass: 'STATEMENT_IMPORT',
                      );
                      if (staged != null) {
                        final id = await media.uploadStaged(staged);
                        if (mounted) setState(() => _mediaObjectId = id);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            Field(label: strings.t('importer.provider'), controller: _provider),
            const SizedBox(height: AppSpace.s4),
            Field(label: strings.t('importer.periodStart'), controller: _start),
            const SizedBox(height: AppSpace.s4),
            Field(label: strings.t('importer.periodEnd'), controller: _end),
            const SizedBox(height: AppSpace.s4),
            HelixText(strings.t('importer.mapping'), style: TypeScale.caption(AppColors.textSecondary)),
            const SizedBox(height: AppSpace.s2),
            Row(
              children: [
                Expanded(child: Field(label: strings.t('importer.date'), controller: _date)),
                const SizedBox(width: AppSpace.s2),
                Expanded(child: Field(label: strings.t('importer.amount'), controller: _amount)),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            Row(
              children: [
                Expanded(child: Field(label: strings.t('importer.card'), controller: _card)),
                const SizedBox(width: AppSpace.s2),
                Expanded(child: Field(label: strings.t('importer.litres'), controller: _litres)),
              ],
            ),
            const SizedBox(height: AppSpace.s3),
            Field(label: strings.t('importer.station'), controller: _station),
            const Spacer(),
            StrandButton(
              label: strings.t('importer.submit'),
              shell: Shell.admin,
              busy: _busy,
              onPressed: _mediaObjectId == null ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
