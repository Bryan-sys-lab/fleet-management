import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../design/components/text.dart';
import '../../design/components/status_badge.dart';
import '../../design/components/states.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Admin fuel pending queue (OCR review list).
class AdminFuelScreen extends ConsumerWidget {
  const AdminFuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    final async = ref.watch(_pendingProvider);
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('review.fuel'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: async.when(
        loading: () => const LoadingBody(),
        error: (e, _) => inlineError(context, e),
        data: (rows) {
          if (rows.isEmpty) return EmptyState(message: strings.t('admin.emptyFuel'));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_pendingProvider),
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final confidence = (row['confidence_score'] as num?)?.toDouble();
                return ListTile(
                  title: HelixText(row['driver_name']?.toString() ?? '', style: TypeScale.body(AppColors.text)),
                  subtitle: HelixText(
                    '${Fmt.moneyParts(row['amount_spent'] as num?)} · ${row['vehicle_plate'] ?? ''}',
                    style: TypeScale.caption(AppColors.textSecondary),
                  ),
                  trailing: confidence != null
                      ? HelixChip(
                          label: Fmt.percent(confidence),
                          color: confidence < 0.7 ? AppColors.statusWarn : AppColors.statusOk,
                        )
                      : null,
                  onTap: () => context.push('/admin/fuel/${row['fuel_purchase_id']}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

final _pendingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final body = await ref.watch(repositoryProvider).adminFuelPending();
  return (body['purchases'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
});
