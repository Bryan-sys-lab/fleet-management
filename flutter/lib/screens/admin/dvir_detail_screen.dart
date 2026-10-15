import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../design/components/card.dart';
import '../../design/components/media_thumb.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/components/status_badge.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// DVIR detail: per-item results (FAIL in brake red), item photos, quarantine
/// banner; read-only note without inspection:read semantics.
class DvirDetailScreen extends ConsumerWidget {
  const DvirDetailScreen({super.key, required this.inspectionId});

  final String inspectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    final async = ref.watch(_inspectionProvider(inspectionId));
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('review.inspections'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: Screen(
        refresh: () async => ref.invalidate(_inspectionProvider(inspectionId)),
        child: async.when(
          loading: () => const LoadingBody(),
          error: (e, _) => inlineError(context, e),
          data: (row) {
            final items = (row['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HelixText(row['template_label']?.toString() ?? '', style: TypeScale.title(AppColors.text)),
                const SizedBox(height: AppSpace.s2),
                HelixText(row['vehicle_label']?.toString() ?? '', style: TypeScale.caption(AppColors.textSecondary)),
                if (row['quarantined'] == true) ...[
                  const SizedBox(height: AppSpace.s3),
                  HelixCard(child: HelixText('${strings.t('detail.quarantine')}: ${row['quarantine_reason'] ?? ''}', style: TypeScale.caption(AppColors.statusPlum))),
                ],
                const SizedBox(height: AppSpace.s4),
                for (final item in items)
                  HelixCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: HelixText(item['label']?.toString() ?? '', style: TypeScale.bodyStrong(AppColors.text))),
                            HelixChip(
                              label: strings.t('detail.${item['result']?.toString().toLowerCase()}'),
                              color: item['result'] == 'FAIL' ? AppColors.statusDanger : AppColors.statusNeutral,
                            ),
                          ],
                        ),
                        if (item['blocker'] == true) ...[
                          const SizedBox(height: AppSpace.s1),
                          HelixText(strings.t('detail.blockerItem'), style: TypeScale.caption(AppColors.statusDanger)),
                        ],
                        if (item['notes'] != null && item['notes'].toString().isNotEmpty) ...[
                          const SizedBox(height: AppSpace.s1),
                          HelixText(item['notes'].toString(), style: TypeScale.caption(AppColors.textSecondary)),
                        ],
                        if (item['photo_count'] != null && (item['photo_count'] as int) > 0) ...[
                          const SizedBox(height: AppSpace.s2),
                          SizedBox(
                            height: 64,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final media in (item['photo_media_ids'] as List? ?? const []))
                                  Padding(
                                    padding: const EdgeInsets.only(right: AppSpace.s2),
                                    child: MediaThumb(mediaId: media.toString()),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpace.s4),
                KeyValueRow(label: strings.t('forms.signature'), value: row['signature_name']?.toString() ?? '—', mono: false),
              ],
            );
          },
        ),
      ),
    );
  }
}

final _inspectionProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(repositoryProvider).inspectionDetail(id);
});
