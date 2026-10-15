import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../design/components/card.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Flag detail — read-only evidence card.
class AnomalyDetailScreen extends ConsumerWidget {
  const AnomalyDetailScreen({super.key, required this.anomalyId});

  final String anomalyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    final async = ref.watch(_anomalyProvider(anomalyId));
    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('anomalies.title'), style: TypeScale.title(AppColors.text))),
      body: Screen(
        refresh: () async => ref.invalidate(_anomalyProvider(anomalyId)),
        child: async.when(
          loading: () => const LoadingBody(),
          error: (e, _) => inlineError(context, e),
          data: (row) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HelixText(row['title']?.toString() ?? row['kind']?.toString() ?? '', style: TypeScale.title(AppColors.text)),
              const SizedBox(height: AppSpace.s2),
              HelixText(
                '${row['domain'] ?? ''} · ${row['severity'] ?? ''}',
                style: TypeScale.caption(AppColors.statusDanger),
              ),
              const SizedBox(height: AppSpace.s4),
              HelixCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HelixText(row['body']?.toString() ?? '', style: TypeScale.body(AppColors.text)),
                    const Divider(height: 24, color: AppColors.line),
                    KeyValueRow(label: strings.t('detail.evidence'), value: row['signal']?.toString() ?? '—', mono: false),
                    if (row['recommended_action'] != null)
                      KeyValueRow(label: strings.t('detail.openRelated'), value: row['recommended_action']!.toString(), mono: false),
                    if (row['vehicle_plate'] != null)
                      KeyValueRow(label: strings.t('vehicle.plate'), value: row['vehicle_plate']!.toString(), mono: false),
                    if (row['driver_name'] != null)
                      KeyValueRow(label: strings.t('drivers.title'), value: row['driver_name']!.toString(), mono: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _anomalyProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(repositoryProvider).anomaly(id);
});
