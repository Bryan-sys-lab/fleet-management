import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../data/providers.dart';
import '../../design/components/card.dart';
import '../../design/components/status_badge.dart';
import '../../design/components/text.dart';
import '../../design/tokens.dart';
import '../common.dart';

/// Live fleet map. Markers coloured by display_state (never colour alone — the
/// legend doubles as the filter); null-fix vehicles are LISTED, never drawn.
class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  final _filters = <String>{};
  Map<String, dynamic>? _selected;

  static const _filterOrder = ['QUARANTINED', 'OFFLINE', 'HOS_ALERT', 'SPEEDING', 'MOVING', 'IDLING', 'PARKED'];

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final states = ref.watch(vehicleStatesProvider);
    return Scaffold(
      appBar: AppBar(
        title: HelixText(strings.t('nav.map'), style: TypeScale.title(AppColors.text)),
        backgroundColor: AppColors.surface,
      ),
      body: states.when(
        loading: () => const LoadingBody(),
        error: (e, _) => inlineError(context, e, retry: () => ref.invalidate(vehicleStatesProvider)),
        data: (rows) {
          final visible = rows.where((v) => _filters.isEmpty || _filters.contains(v['display_state']?.toString())).toList();
          final withFix = visible.where((v) => v['latitude'] != null && v['longitude'] != null).toList();
          final nullFix = visible.where((v) => v['latitude'] == null || v['longitude'] == null).toList();
          final markers = <Marker>{
            for (final v in withFix)
              Marker(
                markerId: MarkerId(v['vehicle_id'] as String),
                position: LatLng((v['latitude'] as num).toDouble(), (v['longitude'] as num).toDouble()),
                icon: BitmapDescriptor.defaultMarkerWithHue(_hueFor(v['display_state']?.toString())),
                infoWindow: InfoWindow(
                  title: v['plate']?.toString(),
                  snippet: v['driver_name']?.toString(),
                ),
                onTap: () => setState(() => _selected = v),
              ),
          };
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(target: LatLng(-1.2921, 36.8219), zoom: 9),
                markers: markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
              // legend / filter chips
              Positioned(
                top: AppSpace.s2,
                left: 0,
                right: 0,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
                  child: Row(
                    children: [
                      for (final state in _filterOrder)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpace.s2),
                          child: FilterChip(
                            label: HelixText(strings.t('status.$state'), style: TypeScale.caption(AppColors.text)),
                            selected: _filters.contains(state),
                            selectedColor: AppColors.adminAccentQuiet,
                            avatar: Text(_glyphFor(state), style: TypeScale.mono(AppColors.textSecondary)),
                            onSelected: (on) => setState(() {
                              on ? _filters.add(state) : _filters.remove(state);
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (nullFix.isNotEmpty)
                Positioned(
                  top: 64,
                  left: AppSpace.s3,
                  right: AppSpace.s3,
                  child: HelixCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HelixText(
                          '${nullFix.length} vehicle(s) have no fix on file — listed, not drawn.',
                          style: TypeScale.caption(AppColors.textSecondary),
                        ),
                        for (final v in nullFix.take(4))
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.s1),
                            child: HelixText('${v['plate']} — ${strings.t('status.OFFLINE')}', style: TypeScale.caption(AppColors.textSecondary)),
                          ),
                      ],
                    ),
                  ),
                ),
              if (_selected != null)
                Positioned(
                  left: AppSpace.s3,
                  right: AppSpace.s3,
                  bottom: AppSpace.s4,
                  child: _VehicleDrawer(
                    vehicle: _selected!,
                    onClose: () => setState(() => _selected = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static double _hueFor(String? state) => switch (state?.toUpperCase()) {
        'QUARANTINED' => BitmapDescriptor.hueMagenta,
        'OFFLINE' => BitmapDescriptor.hueAzure,
        'HOS_ALERT' => BitmapDescriptor.hueOrange,
        'SPEEDING' => BitmapDescriptor.hueRed,
        'MOVING' => BitmapDescriptor.hueGreen,
        'IDLING' => BitmapDescriptor.hueYellow,
        _ => BitmapDescriptor.hueViolet,
      };

  static String _glyphFor(String state) => switch (state) {
        'QUARANTINED' => '✕',
        'OFFLINE' => '○',
        'HOS_ALERT' => '!',
        'SPEEDING' => '▲',
        'MOVING' => '►',
        'IDLING' => '❚❚',
        _ => 'P',
      };
}

class _VehicleDrawer extends StatelessWidget {
  const _VehicleDrawer({required this.vehicle, required this.onClose});

  final Map<String, dynamic> vehicle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = context.s;
    final parsed = vehicleStateFromName(vehicle['display_state'] as String?);
    return HelixCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (parsed != null) StatusBadge(state: parsed, dense: true),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: onClose,
              ),
            ],
          ),
          HelixText('${vehicle['plate'] ?? ''}', style: TypeScale.title(AppColors.text)),
          const SizedBox(height: AppSpace.s2),
          KeyValueRow(label: strings.t('drivers.title'), value: vehicle['driver_name']?.toString() ?? '—', mono: false),
          KeyValueRow(label: strings.t('detail.position'), value: '${vehicle['latitude'] ?? '—'}, ${vehicle['longitude'] ?? '—'}'),
          KeyValueRow(label: strings.t('detail.hos'), value: '${vehicle['next_eligible_clock_in_at'] ?? '—'}', mono: false),
          KeyValueRow(label: strings.t('shift.odometer'), value: '${vehicle['odometer_km'] ?? '—'}'),
          if (vehicle['quarantine_reason'] != null)
            KeyValueRow(label: strings.t('detail.quarantine'), value: vehicle['quarantine_reason'].toString(), mono: false),
        ],
      ),
    );
  }
}

