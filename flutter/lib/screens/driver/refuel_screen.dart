import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/media.dart';
import '../../core/offline/queue.dart';
import '../../design/components/buttons.dart';
import '../../design/components/field.dart';
import '../../design/components/form_shell.dart';
import '../../design/components/photo_capture.dart';
import '../../design/components/screen.dart';
import '../../design/components/sheet_host.dart';
import '../../design/components/text.dart';
import '../../design/components/skeleton.dart';
import '../../design/tokens.dart';
import '../common.dart';
import 'home_state.dart';

/// Photo-first refuel: receipt photo → pump photo → odometer reading → card picker
/// (last-4 typed) → purchased-at → submit. Two staged photos (receipt + pump), one write.
class RefuelScreen extends ConsumerStatefulWidget {
  const RefuelScreen({super.key});

  @override
  ConsumerState<RefuelScreen> createState() => _RefuelScreenState();
}

class _RefuelScreenState extends ConsumerState<RefuelScreen> {
  final _formKey = GlobalKey<FormShellState>();
  final _odometer = TextEditingController();
  final _litres = TextEditingController();
  final _cost = TextEditingController();
  final _last4 = TextEditingController();
  final _station = TextEditingController();
  final _purchasedAt = TextEditingController();
  XFile? _receipt;
  XFile? _pump;
  String? _cardId;
  bool _busy = false;

  Future<void> _pickCard(List<Map<String, dynamic>> cards) async {
    final picked = await SheetHost.show<String>(
      context: context,
      title: context.s.t('forms.pickCard'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final card in cards)
            ListTile(
              title: HelixText(card['label']?.toString() ?? '', style: TypeScale.body(AppColors.text)),
              subtitle: HelixText(
                '${card['provider'] ?? ''}${card['is_pooled'] == true ? ' · ${context.s.t('forms.pooled')}' : ''}',
                style: TypeScale.caption(AppColors.textSecondary),
              ),
              onTap: () => Navigator.of(context).pop(card['id'] as String),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _cardId = picked);
  }

  Future<void> _submit() async {
    final strings = context.s;
    final km = int.tryParse(_odometer.text.trim());
    final shift = await ref.read(activeShiftProvider.future);
    final vehicleId = shift?['vehicle_id'] as String?;
    if (km == null || _receipt == null || _pump == null || vehicleId == null) return;

    setState(() => _busy = true);
    try {
      final media = ref.read(mediaProvider);
      final receipt = await media.stageCapture(
        await _receipt!.readAsBytes(),
        slot: MediaService.slotReceipt,
        ownerKind: 'FUEL_RECEIPT',
        retentionClass: 'RECEIPT',
      );
      final pump = await media.stageCapture(
        await _pump!.readAsBytes(),
        slot: MediaService.slotPump,
        ownerKind: 'FUEL_PURCHASE',
        retentionClass: 'RECEIPT',
      );
      final litres = Fmt.parseDecimal(_litres.text);
      final cost = Fmt.parseDecimal(_cost.text);
      if (receipt == null || pump == null || litres == null || cost == null) {
        setState(() => _busy = false);
        return;
      }
      final purchasedAt = _purchasedAt.text.trim().isEmpty
          ? DateTime.now().toUtc().toIso8601String()
          : '${_purchasedAt.text.trim()}:00+03:00';
      final op = QueueOp(
        method: 'POST',
        path: 'driver/fuel/purchase',
        body: {
          'shift_id': shift?['shift_id'],
          'vehicle_id': vehicleId,
          'odometer_reading': km,
          'receipt_media_object_id': receipt.slot,
          'pump_photo_media_object_id': pump.slot,
          'purchased_at': purchasedAt,
          if (_cardId != null || _last4.text.trim().isNotEmpty)
            'fuel_card_last_four': _cardId ?? _last4.text.trim(),
        },
        uploads: [receipt, pump],
        produces: 'fuel_purchase_id',
      );
      final result = await ref.read(offQueueProvider).submitStaged([op]);
      if (!mounted) return;
      if (result.allSent) {
        _formKey.currentState?.showSent();
      } else {
        _formKey.currentState?.showQueued();
      }
    } on HelixError catch (e) {
      if (!mounted) return;
      _formKey.currentState?.showError(strings.error(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    return Scaffold(
      appBar: AppBar(title: HelixText(strings.t('forms.titleRefuel'), style: TypeScale.title(AppColors.text))),
      body: Screen(
        child: FormShell(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhotoCapture(
                cameras: ref.watch(camerasProvider).valueOrNull ?? const [],
                label: strings.t('forms.receipt'),
                captured: _receipt,
                onCaptured: (file) => setState(() => _receipt = file),
              ),
              const SizedBox(height: AppSpace.s4),
              PhotoCapture(
                cameras: ref.watch(camerasProvider).valueOrNull ?? const [],
                label: strings.t('forms.pump'),
                captured: _pump,
                onCaptured: (file) => setState(() => _pump = file),
              ),
              const SizedBox(height: AppSpace.s4),
              Field(
                label: strings.t('shift.odometer'),
                controller: _odometer,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('forms.litres'), controller: _litres, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('forms.cost'), controller: _cost, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: AppSpace.s4),
              Consumer(
                builder: (context, ref, _) {
                  final cards = ref.watch(fuelCardsProvider);
                  return cards.when(
                    loading: () => Skeleton(height: 56),
                    error: (e, _) => inlineError(context, e),
                    data: (cardsList) => OutlinedButton.icon(
                      icon: Icon(Icons.credit_card, color: AppColors.textSecondary),
                      label: HelixText(
                        _cardId != null
                            ? cardsList.firstWhere((c) => c['id'] == _cardId, orElse: () => {'label': '?'})['label']?.toString() ?? ''
                            : strings.t('forms.pickCard'),
                        style: TypeScale.body(AppColors.text),
                      ),
                      onPressed: () => _pickCard(cardsList),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('forms.cardLast4'), controller: _last4, keyboardType: TextInputType.number),
              const SizedBox(height: AppSpace.s4),
              Field(label: strings.t('forms.station'), controller: _station),
              const SizedBox(height: AppSpace.s4),
              Field(
                label: strings.t('forms.purchasedAt'),
                controller: _purchasedAt,
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: AppSpace.s5),
              StrandButton(
                label: strings.t('actions.submit'),
                shell: Shell.driver,
                onPressed: _busy ? null : _submit,
                busy: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

