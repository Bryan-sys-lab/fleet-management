import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/paged_list.dart';
import '../../design/components/sheet_host.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Maintenance records + inline work-order form.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  final _task = TextEditingController();
  final _vehicle = TextEditingController();
  final _vendor = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _task.dispose();
    _vehicle.dispose();
    _vendor.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _record() async {
    try {
      await ref.read(repositoryProvider).createMaintenance({
        'vehicle_id': _vehicle.text.trim(),
        'task_code': _task.text.trim(),
        if (_vendor.text.trim().isNotEmpty) 'vendor': _vendor.text.trim(),
        if (_cost.text.trim().isNotEmpty) 'cost': double.tryParse(_cost.text.trim()),
        'currency': 'KES',
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ref.invalidate(_maintenanceProvider);
    } on HelixError catch (e) {
      if (mounted) showHelixError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final canRecord = ref.watch(sessionProvider).permissions.contains('maintenance:record');
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('maintenance.title'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: PagedList<Map<String, dynamic>>(
        emptyMessage: strings.t('maintenance.title'),
        loadMore: (cursor) async {
          try {
            return await ref.read(repositoryProvider).page('maintenance', cursor: cursor);
          } on HelixError catch (e) {
            throw HelixErrorLike(strings.error(e.code), actionLabel: strings.actionLabel(e.catalogue.action.name));
          }
        },
        itemBuilder: (context, row) => HelixCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HelixText(row['task_code']?.toString() ?? '', style: TypeScale.bodyStrong(AppColors.text)),
              const SizedBox(height: AppSpace.s1),
              HelixText(
                '${row['vendor'] ?? ''} · ${Fmt.moneyParts(row['cost'] as num?)} · ${Fmt.date(DateTime.tryParse(row['performed_at']?.toString() ?? ''))}',
                style: TypeScale.caption(AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: canRecord
          ? FloatingActionButton(
              backgroundColor: AppColors.adminAccent,
              onPressed: () => SheetHost.show(
                context: context,
                title: strings.t('maintenance.record'),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Field(label: strings.t('maintenance.taskId'), controller: _task),
                      const SizedBox(height: AppSpace.s3),
                      Field(label: strings.t('maintenance.vehicleId'), controller: _vehicle),
                      const SizedBox(height: AppSpace.s3),
                      Field(label: strings.t('maintenance.vendor'), controller: _vendor),
                      const SizedBox(height: AppSpace.s3),
                      Field(label: strings.t('maintenance.cost'), controller: _cost),
                      const SizedBox(height: AppSpace.s3),
                      Field(label: strings.t('forms.notes'), controller: _notes),
                    ],
                  ),
                ),
              ).then((_) => _record()),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

final _maintenanceProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final page = await ref.watch(repositoryProvider).page('maintenance');
  return page.data;
});
