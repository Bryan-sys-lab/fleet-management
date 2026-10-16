import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors.dart';
import '../../data/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/screen.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Tracker pairing: IMEI (15 digits) + vehicle picker + brand, submitted
/// camelCase to the hardware router. The UI sends the IMEI by hand in the
/// shipped path (QR scanning drops out without a barcode dependency).
class TrackerPairScreen extends ConsumerStatefulWidget {
  const TrackerPairScreen({super.key});

  @override
  ConsumerState<TrackerPairScreen> createState() => _TrackerPairScreenState();
}

class _TrackerPairScreenState extends ConsumerState<TrackerPairScreen> {
  final _imei = TextEditingController();
  final _vehicleId = TextEditingController();
  final _sim = TextEditingController();
  String _brand = 'GENERIC_H02';
  bool _busy = false;

  @override
  void dispose() {
    _imei.dispose();
    _vehicleId.dispose();
    _sim.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final strings = context.s;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).pairTracker({
        'vehicleId': _vehicleId.text.trim(),
        'trackerImei': _imei.text.trim(),
        'trackerBrand': _brand,
        if (_sim.text.trim().isNotEmpty) 'trackerSimNumber': _sim.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.t('hardware.paired'))));
      setState(() => _busy = false);
    } on HelixError catch (e) {
      if (!mounted) return;
      showHelixError(context, e);
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final valid = _imei.text.trim().length == 15 && _vehicleId.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('hardware.title'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: Screen(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HelixText(strings.t('hardware.enterManually'), style: TypeScale.body(AppColors.text)),
            const SizedBox(height: AppSpace.s5),
            Field(
              label: strings.t('hardware.imei'),
              controller: _imei,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpace.s4),
            Field(
              label: strings.t('vehicle.title'),
              controller: _vehicleId,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpace.s4),
            HelixText(strings.t('hardware.brand'), style: TypeScale.caption(AppColors.textSecondary)),
            DropdownButtonFormField<String>(
              initialValue: _brand,
              decoration: InputDecoration(filled: true, fillColor: AppColors.surfaceSunk),
              items: const [
                'GENERIC_H02',
                'TELTONIKA',
                'QUECLINK',
                'JIMI',
                'TK_STAR',
                'CALE',
                'SINTRONES',
              ].map((b) => DropdownMenuItem(value: b, child: HelixText(b, style: TypeScale.body(AppColors.text)))).toList(),
              onChanged: (v) => setState(() => _brand = v ?? 'GENERIC_H02'),
            ),
            const SizedBox(height: AppSpace.s4),
            Field(label: strings.t('hardware.sim'), controller: _sim),
            const Spacer(),
            StrandButton(
              label: strings.t('hardware.pair'),
              shell: Shell.admin,
              onPressed: valid && !_busy ? _pair : null,
              busy: _busy,
            ),
          ],
        ),
      ),
    );
  }
}
