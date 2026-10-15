import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/buttons.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Document detail: expiry countdown + evidence metadata + renewal note.
class DocDetailScreen extends ConsumerStatefulWidget {
  const DocDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<DocDetailScreen> createState() => _DocDetailScreenState();
}

class _DocDetailScreenState extends ConsumerState<DocDetailScreen> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final async = ref.watch(_docProvider(widget.documentId));
    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('docs.title'), style: TypeScale.title(AppColors.text))),
      body: Screen(
        refresh: () async => ref.invalidate(_docProvider(widget.documentId)),
        child: async.when(
          loading: () => const LoadingBody(),
          error: (e, _) => inlineError(context, e),
          data: (row) {
            final days = row['days_remaining'] as int?;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HelixText(row['subject_name']?.toString() ?? '', style: TypeScale.title(AppColors.text)),
                const SizedBox(height: AppSpace.s2),
                HelixText(
                  days == null ? '' : days <= 0 ? strings.t('docs.expired') : strings.t('docs.days', {'n': '$days'}),
                  style: TypeScale.caption(days != null && days <= 7 ? AppColors.statusDanger : AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpace.s4),
                HelixCard(
                  child: Column(
                    children: [
                      KeyValueRow(label: strings.t('detail.document'), value: row['document_number']?.toString() ?? '—'),
                      KeyValueRow(label: strings.t('detail.issuerName'), value: row['issuer']?.toString() ?? '—'),
                      KeyValueRow(
                        label: strings.t('detail.expires'),
                        value: Fmt.date(DateTime.tryParse(row['expires_on']?.toString() ?? '')),
                      ),
                    ],
                  ),
                ),
                if (row['renewal_note'] != null) ...[
                  const SizedBox(height: AppSpace.s4),
                  HelixCard(child: HelixText(row['renewal_note'].toString(), style: TypeScale.body(AppColors.text))),
                ],
                const SizedBox(height: AppSpace.s4),
                Field(label: strings.t('docs.renewalNote'), controller: _note, maxLines: 3),
                const SizedBox(height: AppSpace.s3),
                SizedBox(
                  width: double.infinity,
                  child: StrandButton(
                    label: strings.t('docs.saveNote'),
                    shell: Shell.driver,
                    onPressed: () async {
                      if (_note.text.trim().isEmpty) return;
                      try {
                        await ref.read(repositoryProvider).renewalNote(widget.documentId, _note.text.trim());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(strings.t('docs.noteSaved'))));
                          ref.invalidate(_docProvider(widget.documentId));
                        }
                      } on HelixError catch (e) {
                        if (context.mounted) showHelixError(context, e);
                      }
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

final _docProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(repositoryProvider).document(id);
});
