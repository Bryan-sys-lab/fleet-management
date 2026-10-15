import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/screen.dart';
import '../../design/components/segmented.dart';
import '../../design/components/text.dart';
import '../../design/components/status_badge.dart';
import '../../design/components/states.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Privacy / DSAR: request export, my requests, tenant-wide requests.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  final _notes = TextEditingController();
  String _scope = 'mine';

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final canViewTenant = ref.watch(sessionProvider).permissions.contains('privacy:view_requests_tenant');
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('privacy.title'), style: TypeScale.title(AppColors.text)),
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
                  HelixText(strings.t('privacy.exportHelp'), style: TypeScale.body(AppColors.textSecondary)),
                  const SizedBox(height: AppSpace.s3),
                  Field(label: strings.t('privacy.notes'), controller: _notes),
                  const SizedBox(height: AppSpace.s3),
                  StrandButton(
                    label: strings.t('privacy.requestExport'),
                    shell: Shell.admin,
                    onPressed: () async {
                      try {
                        await ref.read(repositoryProvider).createExportRequest({
                          if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
                        });
                        if (context.mounted) setState(() {});
                      } on HelixError catch (e) {
                        if (context.mounted) showHelixError(context, e);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            if (canViewTenant)
              Segmented<String>(
                value: _scope,
                onChanged: (v) => setState(() => _scope = v),
                options: [
                  SegmentedOption('mine', strings.t('privacy.myRequests')),
                  SegmentedOption('tenant', strings.t('privacy.tenantRequests')),
                ],
              ),
            const SizedBox(height: AppSpace.s4),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _requests(ref, _scope == 'tenant' && canViewTenant),
              builder: (context, snapshot) {
                final rows = snapshot.data ?? const [];
                if (rows.isEmpty) return EmptyState(message: strings.t('privacy.noRequests'));
                return Column(
                  children: [
                    for (final row in rows)
                      HelixCard(
                        child: Row(
                          children: [
                            HelixChip(
                              label: '${row['request_type'] ?? ''}',
                              color: AppColors.statusNeutral,
                            ),
                            const SizedBox(width: AppSpace.s3),
                            Expanded(
                              child: HelixText(
                                '${row['status'] ?? ''} · ${Fmt.date(DateTime.tryParse(row['created_at']?.toString() ?? ''))}',
                                style: TypeScale.caption(AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _requests(WidgetRef ref, bool tenant) async {
    final repo = ref.watch(repositoryProvider);
    final page = await repo.page(tenant ? 'privacy/requests' : 'privacy/export-request');
    return page.data;
  }
}
