import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../data/providers.dart';
import '../../design/components/segmented.dart';
import '../../design/components/text.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/sheet_host.dart';
import '../../design/components/status_badge.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Vehicle fleet list (GET /vehicles returns a raw array — the client caps at
/// one page and manages its own window).
class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  List<Map<String, dynamic>> _vehicles = const [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await ref.read(repositoryProvider).rawList('vehicles', query: {'limit': 200});
      if (!mounted) return;
      setState(() {
        _vehicles = rows.take(200).toList();
        _loading = false;
      });
    } on HelixError catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showHelixError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final canUpdate = ref.watch(sessionProvider).permissions.contains('asset:update');
    final visible = _vehicles.where((v) {
      if (_filter == 'operational') return v['is_operational'] == true;
      if (_filter == 'non-operational') return v['is_operational'] != true;
      return true;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('vehicle.title'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const LoadingBody()
          : RefreshIndicator(
              onRefresh: _load,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: Segmented<String>(
                      value: _filter,
                      onChanged: (v) => setState(() => _filter = v),
                      options: [
                        SegmentedOption('all', strings.t('anomalies.all')),
                        SegmentedOption('operational', strings.t('status.OPERATIONAL')),
                        SegmentedOption('non-operational', strings.t('vehicle.nonOperationalReason')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final vehicle = visible[index];
                        return ListTile(
                          title: HelixText('${vehicle['license_plate'] ?? ''}', style: TypeScale.mono(AppColors.text)),
                          subtitle: HelixText(
                            '${vehicle['make'] ?? ''} ${vehicle['model'] ?? ''} · ${vehicle['odometer_km'] ?? '—'} km',
                            style: TypeScale.caption(AppColors.textSecondary),
                          ),
                          trailing: vehicle['is_operational'] != true
                              ? HelixChip(label: '✕', color: AppColors.statusDanger)
                              : HelixChip(label: '►', color: AppColors.statusOk),
                          onTap: () => context.push('/admin/vehicle-issues/${vehicle['id']}'),
                        );
                      },
                    ),
                  ),
                  if (canUpdate)
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add, color: AppColors.adminAccent),
                        label: HelixText(strings.t('vehicle.create'), style: TypeScale.button(AppColors.adminAccent)),
                        onPressed: _createVehicle,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /// Create vehicle via a bottom sheet (POST /vehicles).
  Future<void> _createVehicle() async {
    final strings = context.s;
    final plate = TextEditingController();
    final make = TextEditingController();
    final model = TextEditingController();
    final year = TextEditingController();
    String vehicleClass = 'TRACTOR';
    await SheetHost.show(
      context: context,
      title: strings.t('vehicle.create'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Field(label: strings.t('vehicle.plate'), controller: plate),
            const SizedBox(height: AppSpace.s3),
            Field(label: strings.t('vehicle.make'), controller: make),
            const SizedBox(height: AppSpace.s3),
            Field(label: strings.t('vehicle.model'), controller: model),
            const SizedBox(height: AppSpace.s3),
            Field(label: 'Year', controller: year, keyboardType: TextInputType.number),
            const SizedBox(height: AppSpace.s3),
            DropdownButtonFormField<String>(
              initialValue: vehicleClass,
              decoration: const InputDecoration(filled: true, fillColor: AppColors.surfaceSunk),
              items: ['TRACTOR', 'RIGID', 'VAN', 'PICKUP']
                  .map((c) => DropdownMenuItem(value: c, child: HelixText(c, style: TypeScale.body(AppColors.text))))
                  .toList(),
              onChanged: (v) => vehicleClass = v ?? 'TRACTOR',
            ),
            const SizedBox(height: AppSpace.s4),
            StrandButton(
              label: strings.t('actions.save'),
              shell: Shell.admin,
              onPressed: () async {
                final navigator = Navigator.of(context);
                try {
                  await ref.read(repositoryProvider).createVehicle({
                    'license_plate': plate.text.trim(),
                    'vehicle_class': vehicleClass,
                    if (make.text.trim().isNotEmpty) 'make': make.text.trim(),
                    if (model.text.trim().isNotEmpty) 'model': model.text.trim(),
                    if (year.text.trim().isNotEmpty) 'year': int.tryParse(year.text.trim()),
                  });
                  navigator.pop();
                  ref.invalidate(vehiclesProvider);
                  await _load();
                } on HelixError catch (e) {
                  if (mounted) showHelixError(context, e);
                }
              },
            ),
          ],
        ),
      ),
    );
    plate.dispose();
    make.dispose();
    model.dispose();
    year.dispose();
  }
}
