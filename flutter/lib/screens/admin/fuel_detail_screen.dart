import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../data/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/card.dart';
import '../../design/components/field.dart';
import '../../design/components/gauge_picker.dart';
import '../../design/components/media_thumb.dart';
import '../../design/components/screen.dart';
import '../../design/components/sheet_host.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Fuel purchase detail: KES amounts in mono, OCR confidence, gauge
/// before/after/delta, and the three gated actions — verify (optional
/// adjusted litres), reject (reason), clear payment.
class FuelDetailScreen extends ConsumerStatefulWidget {
  const FuelDetailScreen({super.key, required this.purchaseId});

  final String purchaseId;

  @override
  ConsumerState<FuelDetailScreen> createState() => _FuelDetailScreenState();
}

class _FuelDetailScreenState extends ConsumerState<FuelDetailScreen> {
  final _reason = TextEditingController();
  final _adjusted = TextEditingController();
  bool _busy = false;

  Future<void> _verify({String? rejectReason, bool clearPayment = false}) async {
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'action': rejectReason != null
            ? 'REJECT'
            : clearPayment
                ? 'CLEAR_PAYMENT'
                : 'VERIFY',
        'reason': ?rejectReason,
        if (_adjusted.text.trim().isNotEmpty) 'adjusted_litres': double.tryParse(_adjusted.text.trim()),
      };
      await ref.read(repositoryProvider).verifyFuel(widget.purchaseId, body);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on HelixError catch (e) {
      if (mounted) showHelixError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askRejectReason() async {
    final reason = await SheetHost.show<String>(
      context: context,
      title: context.s.t('detail.rejectReason'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s5),
        child: Field(label: context.s.t('detail.rejectReason'), controller: _reason, maxLines: 2),
      ),
    );
    if (reason != null) await _verify(rejectReason: _reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final canVerify = ref.watch(sessionProvider).permissions.contains('fuel:verify');
    final canAdjust = ref.watch(sessionProvider).permissions.contains('fuel:adjust');
    final canClear = ref.watch(sessionProvider).permissions.contains('fuel:clear_payment');
    final async = ref.watch(_purchaseProvider(widget.purchaseId));
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('review.fuel'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: Screen(
        refresh: () async => ref.invalidate(_purchaseProvider(widget.purchaseId)),
        child: async.when(
          loading: () => const LoadingBody(),
          error: (e, _) => inlineError(context, e),
          data: (row) {
            final confidence = (row['confidence_score'] as num?)?.toDouble();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HelixText(row['driver_name']?.toString() ?? '', style: TypeScale.title(AppColors.text)),
                const SizedBox(height: AppSpace.s2),
                HelixText('${row['vehicle_plate'] ?? ''} · ${row['station_name'] ?? ''}', style: TypeScale.caption(AppColors.textSecondary)),
                const SizedBox(height: AppSpace.s4),
                HelixCard(
                  child: Column(
                    children: [
                      KeyValueRow(label: strings.t('forms.litres'), value: '${row['liters_pumped'] ?? '—'}'),
                      KeyValueRow(label: strings.t('forms.cost'), value: Fmt.moneyParts(row['amount_spent'] as num?)),
                      KeyValueRow(label: strings.t('shift.odometer'), value: '${row['odometer_km'] ?? '—'}'),
                      KeyValueRow(label: strings.t('forms.cardLast4'), value: '${row['fuel_card_last_four'] ?? row['last_four'] ?? '—'}'),
                      KeyValueRow(
                        label: 'OCR',
                        value: confidence == null ? '—' : Fmt.percent(confidence),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s4),
                Row(
                  children: [
                    Column(
                      children: [
                        HelixText(strings.t('detail.gaugeBefore'), style: TypeScale.caption(AppColors.textSecondary)),
                        const SizedBox(height: AppSpace.s2),
                        GaugeBar(gauge: row['gauge_before'] as String?),
                      ],
                    ),
                    const SizedBox(width: AppSpace.s5),
                    Column(
                      children: [
                        HelixText(strings.t('detail.gaugeAfter'), style: TypeScale.caption(AppColors.textSecondary)),
                        const SizedBox(height: AppSpace.s2),
                        GaugeBar(gauge: row['gauge_after'] as String?),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s4),
                if (row['receipt_media_object_id'] != null)
                  MediaThumb(mediaId: row['receipt_media_object_id'].toString()),
                const SizedBox(height: AppSpace.s4),
                if (canAdjust) ...[
                  Field(
                    label: strings.t('detail.adjustLitres'),
                    controller: _adjusted,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: AppSpace.s4),
                ],
                if (canVerify) ...[
                  StrandButton(
                    label: strings.t('admin.verify'),
                    shell: Shell.admin,
                    busy: _busy,
                    onPressed: () => _verify(),
                  ),
                  const SizedBox(height: AppSpace.s2),
                  QuietButton(label: strings.t('admin.reject'), onPressed: _askRejectReason),
                ],
                if (canClear) ...[
                  const SizedBox(height: AppSpace.s2),
                  QuietButton(label: strings.t('admin.clearPayment'), onPressed: () => _verify(clearPayment: true)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

final _purchaseProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final page = await ref.watch(repositoryProvider).page('fuel/reconciliation-inbox', query: {'verified': 'false', 'limit': 200});
  final row = page.data.firstWhere(
    (e) => e['fuel_purchase_id'] == id,
    orElse: () => {'fuel_purchase_id': id},
  );
  return row;
});
