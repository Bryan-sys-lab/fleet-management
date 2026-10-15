import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/providers.dart';
import '../../design/components/card.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/components/status_badge.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Admin Overview: attention cards (exact counts where analytics has them,
/// "(at least)" where a first-page bound is all we know), fleet status row,
/// KPI strip. Admin shell = violet strand.
class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.s;
    final analyticsAsync = ref.watch(analyticsProvider);
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('tabs.overview'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: Screen(
        refresh: () async => ref.invalidate(analyticsProvider),
        child: analyticsAsync.when(
          loading: () => const LoadingBody(),
          error: (e, _) => inlineError(context, e, retry: () => ref.invalidate(analyticsProvider)),
          data: (a) {
            final counts = a['kpis'] as Map<String, dynamic>? ?? const {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(strings.t('dash.attention')),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpace.s3,
                  crossAxisSpacing: AppSpace.s3,
                  childAspectRatio: 1.6,
                  children: [
                    _AttentionCard(
                      label: strings.t('admin.accidents'),
                      count: counts['open_accidents'] as int? ?? a['open_accidents'] as int? ?? 0,
                      exact: true,
                      color: AppColors.statusDanger,
                      onTap: () => context.go('/admin/accidents'),
                    ),
                    _AttentionCard(
                      label: strings.t('review.inspections'),
                      count: counts['pending_dvir'] as int? ?? a['pending_dvir'] as int? ?? 0,
                      exact: true,
                      color: AppColors.statusWarn,
                      onTap: () => context.go('/admin/review'),
                    ),
                    _AttentionCard(
                      label: strings.t('review.fuel'),
                      count: counts['anomalies'] as int? ?? a['anomalies_open'] as int? ?? 0,
                      exact: true,
                      color: AppColors.statusAmber,
                      onTap: () => context.go('/admin/fuel-pending'),
                    ),
                    _AttentionCard(
                      label: strings.t('docs.title'),
                      count: counts['expiring_docs'] as int? ?? a['expiring_docs'] as int? ?? 0,
                      exact: true,
                      color: AppColors.statusInfo,
                      onTap: () => context.go('/admin/inbox?initial=docs'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s5),
                ScreenHeader(strings.t('dashDetail.title')),
                HelixCard(
                  child: Column(
                    children: [
                      KeyValueRow(label: strings.t('dashDetail.distanceKm'), value: '${counts['distanceKm'] ?? '—'}'),
                      KeyValueRow(label: strings.t('dashDetail.fuelCost'), value: '${counts['fuelCost'] ?? '—'}'),
                      KeyValueRow(label: strings.t('dashDetail.anomalies'), value: '${counts['anomalies'] ?? '—'}'),
                      KeyValueRow(label: strings.t('dashDetail.vehicles'), value: '${counts['vehicles'] ?? '—'}'),
                      KeyValueRow(label: strings.t('dashDetail.drivers'), value: '${counts['drivers'] ?? '—'}'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s5),
                ScreenHeader(strings.t('dash.fleet')),
                HelixCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in {'Accidents': '/admin/accidents', 'Review': '/admin/review', 'Map': '/admin/map'}.entries)
                        ListTile(
                          leading: HelixChip(label: entry.key, color: AppColors.adminAccent, glyph: '►'),
                          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          onTap: () => context.go(entry.value),
                        ),
                    ],
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

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.label,
    required this.count,
    required this.exact,
    required this.color,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool exact;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HelixCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HelixText('$count', style: TypeScale.mono(color, size: 28)),
          const SizedBox(height: AppSpace.s1),
          HelixText(label, style: TypeScale.caption(AppColors.textSecondary)),
          if (!exact)
            HelixText('at least', style: TypeScale.caption(AppColors.textTertiary)),
        ],
      ),
    );
  }
}

