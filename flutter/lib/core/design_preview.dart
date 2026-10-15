import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'kv_store.dart';
import 'package:flutter/foundation.dart';
import 'session.dart';

/// OFFLINE DESIGN PREVIEW — a local, fixture-backed bypass so the UI can be
/// reviewed without the backend. Debug builds only: the entry point is guarded
/// by [kDebugMode] and the preview session never leaves the device.
///
/// It is deliberately NOT a second app or a mock server: it is a Dio adapter
/// that answers the app's real endpoints with canned rows, so every screen,
/// state and shell switch is exercisable in the same code path as production.
class DesignPreview {
  DesignPreview._();

  /// All permission codes the seed grants (so every control renders).
  static const List<String> permissions = [
    'accident:acknowledge', 'accident:close', 'accident:read', 'accident:report', 'accident:update',
    'asset:create', 'asset:lift_quarantine', 'asset:quarantine', 'asset:read', 'asset:update',
    'assignment:create', 'assignment:read', 'assignment:update', 'audit:read', 'config:manage',
    'config:read', 'device:revoke', 'document:manage', 'document:read', 'expense:approve',
    'expense:read', 'expense:submit', 'fuel:adjust', 'fuel:card_manage', 'fuel:clear_payment',
    'fuel:read', 'fuel:reconcile', 'fuel:record_gauge', 'fuel:submit_purchase', 'fuel:verify',
    'geofence:manage', 'geofence:read', 'hos:override', 'hos:read', 'inspection:read',
    'inspection:submit', 'inspection:template_manage', 'maintenance:manage', 'maintenance:read',
    'maintenance:record', 'manage_own_mfa', 'revoke_device', 'notification:manage', 'payroll:export',
    'recovery:manage', 'report:export', 'report:read', 'role:manage', 'shift:clock_in',
    'shift:clock_out', 'shift:flag', 'shift:force_close', 'shift:read_all', 'shift:read_own',
    'shift:unlock', 'shift:verify', 'telemetry:read_history', 'telemetry:read_live', 'trailer:swap',
    'user:manage', 'user:read', 'anomaly:read', 'notification:read', 'training:read',
    'training:manage', 'training:complete', 'training:review', 'onboarding:read',
    'onboarding:submit', 'onboarding:review', 'vehicle:report', 'privacy:request_own',
    'privacy:view_requests_tenant',
  ];

  static const List<String> roles = ['DRIVER', 'FLEET_MANAGER', 'ADMIN'];
  static const String userId = 'preview-user-0001';
  static const String email = 'preview@helix.app';
  static const String phone = '+254700000000';

  /// Stable UUIDs for chained detail screens.
  static const shiftId = '11111111-1111-4111-8111-111111111111';
  static const accidentId = '22222222-2222-4222-8222-222222222222';
  static const fuelPurchaseId = '33333333-3333-4333-8333-333333333333';
  static const inspectionId = '44444444-4444-4444-8444-444444444444';
  static const driverUserId = '55555555-5555-4555-8555-555555555555';
  static const vehicleId = '66666666-6666-4666-8666-666666666666';

  static String idForRole(int n) =>
      '${(0x10000000 + n).toRadixString(16)}-0000-4000-8000-000000000000';

  /// Installs the preview session: both roles, every permission, consent
  /// accepted, and the ADMIN shell active.
  static Future<void> install(SessionService session) async {
    await session.store.write(StoreKeys.userId, userId);
    await session.store.write(StoreKeys.roles, jsonEncode(roles));
    await session.store.write(StoreKeys.permissions, jsonEncode(permissions));
    await session.store.write(StoreKeys.consentVersion, '2026.1');
    await session.store.write(StoreKeys.lastAuthAt, '${DateTime.now().toUtc().millisecondsSinceEpoch}');
    await session.store.write(StoreKeys.offlineUntil,
        '${DateTime.now().toUtc().add(const Duration(days: 365)).millisecondsSinceEpoch}');
    await session.enterPreview();
  }

  /// True when the session is the offline preview (never true in release).
  static bool get isActive => kDebugMode && _active;
  static bool _active = false;
  static void markActive() => _active = true;
}

/// A Dio adapter that answers from fixtures. Only the endpoints the design
/// review needs; unknown routes return an empty payload rather than throwing,
/// so no screen is blocked by a missing fixture row.
class PreviewAdapter implements HttpClientAdapter {
  PreviewAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path.replaceFirst(RegExp(r'^/'), '');
    final body = _respond(options.method, path, options.queryParameters);
    return ResponseBody.fromString(
      jsonEncode(body ?? <String, dynamic>{}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Object? _respond(String method, String path, Map<String, dynamic> query) {
    if (path.startsWith('auth/')) return _authBody();
    final page = query['cursor'] as String?;
    // computed keys (string interpolation is not a valid switch case)
    final shiftVerificationKey = 'shifts/${DesignPreview.shiftId}/verification';
    final inspectionKey = 'inspections/${DesignPreview.inspectionId}';
    final anomalyKey = 'anomalies/${DesignPreview.idForRole(6)}';
    final docKey = 'documents/${DesignPreview.idForRole(7)}';
    final accidentKey = 'accidents/${DesignPreview.accidentId}';
    final telemetryKey = 'accidents/${DesignPreview.accidentId}/telemetry/verify';
    final driverKey = 'drivers/${DesignPreview.driverUserId}';
    final vehicleKey = 'vehicles/${DesignPreview.vehicleId}';
    final issuesKey = 'vehicles/${DesignPreview.vehicleId}/issues';
    switch (path) {
      case 'drivers/me/onboarding':
        return {
          'id': DesignPreview.idForRole(1),
          'driver_id': DesignPreview.driverUserId,
          'full_name': 'Amina Wanjiru',
          'licence_number': 'DL-991-CE',
          'licence_class': 'CE',
          'background_check_status': 'CLEARED',
          'onboarding_complete': true,
          'assigned_vehicle_id': DesignPreview.vehicleId,
        };
      case 'drivers/me/assignment':
        return {
          'id': DesignPreview.idForRole(2),
          'vehicle_id': DesignPreview.vehicleId,
          'vehicle_label': 'KAA 123A · Scania R500',
          'trailer_id': null,
        };
      case 'drivers/me/training-status':
        return {'completed_lessons': [1, 2], 'total_lessons': 4, 'all_complete': false};
      case 'shifts/me/active':
        return {
          'shift_id': DesignPreview.shiftId,
          'state': 'OPEN',
          'vehicle_id': DesignPreview.vehicleId,
          'vehicle_label': 'KAA 123A · Scania R500',
          'trailer_id': null,
          'clock_in_at': DateTime.now().toUtc().subtract(const Duration(hours: 4)).toIso8601String(),
        };
      case 'shifts/me':
      case 'shifts/verification-inbox':
        return _page([
          _shiftRow(DesignPreview.shiftId, 'PENDING', 'OPEN', 'Amina Wanjiru', 'KAA 123A'),
          _shiftRow(DesignPreview.idForRole(3), 'VERIFIED', 'CLOSED', 'Brian Otieno', 'KCB 771B'),
        ], page);
      case _ when path == shiftVerificationKey:
        return _shiftRow(DesignPreview.shiftId, 'PENDING', 'OPEN', 'Amina Wanjiru', 'KAA 123A');
      case 'inspections/templates':
        return {
          'templates': [
            {
              'template_id': DesignPreview.idForRole(4),
              'label': 'Daily tractor check',
              'subject': 'VEHICLE',
              'items': [
                {'template_item_id': 't1', 'code': 'BRAKES', 'label_en': 'Brakes', 'label_sw': 'Breki', 'severity': 'BLOCKER', 'input_type': 'PASS_FAIL', 'is_required': true, 'sequence': 1},
                {'template_item_id': 't2', 'code': 'REEFER', 'label_en': 'Reefer temp', 'label_sw': 'Joto ya reefer', 'severity': 'WARNING', 'input_type': 'NUMERIC', 'unit': '°C', 'min_value': -25, 'max_value': 5, 'is_required': true, 'sequence': 2},
              ],
            },
          ],
        };
      case 'inspections':
      case 'inspections/me':
        return _page([
          _inspectionRow(),
        ], page);
      case _ when path == inspectionKey:
        return {
          ..._inspectionRow(),
          'vehicle_label': 'KAA 123A · Scania R500',
          'odometer_km': 128400,
          'signature_name': 'Amina Wanjiru',
          'review_note': null,
          'quarantined': false,
          'items': [
            {'template_item_id': 't1', 'label': 'Brakes', 'result': 'FAIL', 'notes': 'Soft pedal', 'photo_count': 1, 'photo_media_ids': ['m1'], 'blocker': true},
            {'template_item_id': 't2', 'label': 'Reefer temp', 'result': 'PASS', 'notes': null, 'photo_count': 0, 'photo_media_ids': [], 'blocker': false},
          ],
        };
      case 'fuel/cards':
        return {
          'cards': [
            {'id': DesignPreview.idForRole(5), 'label': 'Fleet card 1', 'provider': 'VISA', 'is_pooled': true, 'assigned_vehicle_id': DesignPreview.vehicleId},
          ],
        };
      case 'fuel/reconciliation-inbox':
      case 'admin/fuel/pending':
        return _page([_fuelRow()], page);
      case 'fuel/reconciliation-inbox?verified=false':
        return _page([_fuelRow()], page);
      case 'dashboard/vehicle-states':
        return {
          'vehicles': [
            _vehicleStateRow('KAA 123A', 'Amina Wanjiru', 'MOVING'),
            _vehicleStateRow('KCB 771B', 'Brian Otieno', 'IDLING'),
            _vehicleStateRow('KDG 442C', 'Cynthia Muthoni', 'OFFLINE'),
            _vehicleStateRow('KDE 908D', 'Daniel Kiprop', 'QUARANTINED'),
          ],
        };
      case 'anomalies':
        return _page([
          {'id': DesignPreview.idForRole(6), 'domain': 'FUEL', 'severity': 'CRITICAL', 'kind': 'FUEL_ANOMALY', 'detected_at': DateTime.now().toUtc().toIso8601String(), 'detail': 'Gauge change too high'},
        ], page);
      case _ when path == anomalyKey:
        return {
          'id': DesignPreview.idForRole(6),
          'domain': 'FUEL',
          'severity': 'CRITICAL',
          'kind': 'FUEL_ANOMALY',
          'title': 'Fuel volume implausible',
          'body': 'The receipt shows 180 litres but the tank holds 120.',
          'signal': {'gauge_delta': 0.4, 'receipt_litres': 180},
          'recommended_action': 'Verify the purchase and call the station.',
          'linked_entity_type': 'VEHICLE',
          'vehicle_plate': 'KAA 123A',
          'driver_name': 'Amina Wanjiru',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
      case 'documents/expiring':
        return _page([
          {'document_id': DesignPreview.idForRole(7), 'document_type': 'INSURANCE', 'subject_name': 'KAA 123A', 'subject_type': 'VEHICLE', 'expires_on': DateTime.now().add(const Duration(days: 3)).toIso8601String().substring(0, 10), 'days_remaining': 3, 'is_blocking': true},
        ], page);
      case _ when path == docKey:
        return {
          'document_id': DesignPreview.idForRole(7),
          'document_type': 'INSURANCE',
          'subject_name': 'KAA 123A',
          'document_number': 'INS-88213',
          'issuer': 'APA Insurance',
          'expires_on': DateTime.now().add(const Duration(days: 3)).toIso8601String().substring(0, 10),
          'days_remaining': 3,
          'is_blocking': true,
        };
      case 'notifications':
        return _page([
          {'id': DesignPreview.idForRole(8), 'title': 'Shift verified', 'body': 'Your 14 Oct shift was verified.', 'priority': 'NORMAL', 'status': 'QUEUED', 'created_at': DateTime.now().toUtc().toIso8601String(), 'payload': {'entity': 'notifications'}},
          {'id': DesignPreview.idForRole(9), 'title': 'Fuel flagged', 'body': 'Your refuel needs review.', 'priority': 'HIGH', 'status': 'SENT', 'created_at': DateTime.now().toUtc().toIso8601String(), 'payload': {}},
        ], page);
      case 'notifications/count':
        return {'total': 3, 'unread': 2};
      case 'reports/analytics':
      case 'analytics/company':
        return {
          'tenant_id': DesignPreview.idForRole(10),
          'from': '2026-10-01',
          'to': '2026-10-14',
          'kpis': {
            'vehicles': 12,
            'drivers': 18,
            'distanceKm': 4108.5,
            'fuelCost': 9122250.00,
            'anomalies': 7,
          },
          'managers': [],
          'active_fleet': 12,
          'open_accidents': 1,
          'pending_dvir': 3,
          'fuel_spend_30d': 9122250.00,
          'expiring_docs': 5,
          'anomalies_open': 7,
        };
      case 'accidents/me':
        return _page([_accidentRow()], page);
      case _ when path == accidentKey:
        return {
          ..._accidentRow(),
          'driver_statement': 'A boda hit the trailer at the roundabout.',
          'telemetry_available': true,
          'seconds_to_escalation': 184,
          'escalation_tier': 1,
        };
      case _ when path == telemetryKey:
        return {'all_valid': true, 'rows': []};
      case 'drivers':
        return _page([
          _driverRow(DesignPreview.driverUserId, 'Amina Wanjiru', 'ACTIVE', true),
          _driverRow(DesignPreview.idForRole(11), 'Brian Otieno', 'SUSPENDED', false),
        ], page);
      case _ when path == driverKey:
        return {
          ..._driverRow(DesignPreview.driverUserId, 'Amina Wanjiru', 'ACTIVE', true),
          'devices': [
            {'device_id': DesignPreview.idForRole(12), 'platform': 'android', 'last_seen_at': DateTime.now().toUtc().toIso8601String()},
          ],
          'roles': ['DRIVER'],
        };
      case 'vehicles':
        // GET /vehicles is a bare array in the contract
        return <Map<String, dynamic>>[
          {'id': DesignPreview.vehicleId, 'license_plate': 'KAA 123A', 'vehicle_class': 'TRACTOR', 'make': 'Scania', 'model': 'R500', 'year': 2021, 'is_operational': true, 'current_odometer_km': 128400, 'status': 'AVAILABLE'},
          {'id': DesignPreview.idForRole(13), 'license_plate': 'KCB 771B', 'vehicle_class': 'RIGID', 'make': 'Isuzu', 'model': 'FRR', 'year': 2019, 'is_operational': true, 'current_odometer_km': 88120, 'status': 'IN_USE'},
          {'id': DesignPreview.idForRole(14), 'license_plate': 'KDG 442C', 'vehicle_class': 'VAN', 'make': 'Toyota', 'model': 'Hiace', 'year': 2022, 'is_operational': false, 'current_odometer_km': 45110, 'status': 'MAINTENANCE'},
        ];
      case _ when path == vehicleKey:
        return {'id': DesignPreview.vehicleId, 'license_plate': 'KAA 123A', 'is_operational': true, 'current_odometer_km': 128400};
      case _ when path == issuesKey:
        return _page([
          {'id': DesignPreview.idForRole(15), 'category': 'MECHANICAL', 'severity': 'HIGH', 'description': 'Air leak on the rear brake line.', 'created_at': DateTime.now().toUtc().toIso8601String()},
        ], page);
      case 'trailer':
        return {
          'trailers': [
            {'id': DesignPreview.idForRole(16), 'license_plate': 'TR 2211', 'trailer_type': 'REEFER', 'status': 'AVAILABLE', 'is_operational': true, 'current_vehicle_id': null},
          ],
        };
      case 'training/lessons':
        return _page([
          {'id': DesignPreview.idForRole(17), 'course_code': 'DEF-101', 'title': 'Defensive driving', 'course_title': 'Safety induction', 'is_mandatory': true, 'duration_minutes': 45, 'order_index': 1},
        ], page);
      case 'training/roster':
        return _page([
          {'id': DesignPreview.idForRole(18), 'driver_name': 'Amina Wanjiru', 'lesson_title': 'Defensive driving', 'course_title': 'Safety induction', 'status': 'COMPLETED', 'completed_at': DateTime.now().toUtc().toIso8601String()},
        ], page);
      case 'maintenance':
        return _page([
          {'id': DesignPreview.idForRole(19), 'task_code': 'OIL-40K', 'vendor': 'Scania Kenya', 'cost': 24500.00, 'performed_at': DateTime.now().toUtc().toIso8601String()},
        ], page);
      case 'privacy/export-request':
      case 'privacy/requests':
        return _page([
          {'id': DesignPreview.idForRole(20), 'request_type': 'EXPORT', 'status': 'READY', 'created_at': DateTime.now().toUtc().toIso8601String()},
        ], page);
      case 'admin/hardware/pending':
        return {
          'trackers': [
            {'imei': '356938035643809', 'vehiclePlate': 'KAA 123A', 'brand': 'TELTONIKA', 'status': 'ONLINE', 'pairedAt': DateTime.now().toUtc().toIso8601String(), 'lastPing': DateTime.now().toUtc().toIso8601String()},
          ],
        };
      case 'me/consent':
        return {'consented': true, 'current_version': '2026.1', 'required_version': '2026.1'};
      default:
        return {'data': const [], 'next_cursor': null, 'has_more': false};
    }
  }

  Map<String, dynamic> _authBody() => {
        'token_type': 'Bearer',
        'access_token': 'preview-access-token',
        'access_token_expires_at': DateTime.now().toUtc().add(const Duration(days: 365)).toIso8601String(),
        'refresh_token': 'preview-refresh-token',
        'refresh_token_expires_at': DateTime.now().toUtc().add(const Duration(days: 365)).toIso8601String(),
        'session_id': DesignPreview.idForRole(21),
        'user_id': DesignPreview.userId,
        'email': DesignPreview.email,
        'phone': DesignPreview.phone,
        'roles': DesignPreview.roles,
        'permissions': DesignPreview.permissions,
        'locale': 'en',
      };

  Map<String, dynamic> _page(List<Map<String, dynamic>> data, String? cursor) => {
        'data': data,
        'next_cursor': null,
        'has_more': false,
      };

  Map<String, dynamic> _shiftRow(String id, String verification, String state, String driver, String plate) => {
        'shift_id': id,
        'driver_id': DesignPreview.driverUserId,
        'driver_name': driver,
        'vehicle_id': DesignPreview.vehicleId,
        'vehicle_plate': plate,
        'operational_date': '2026-10-14',
        'verification_status': verification,
        'state': state,
        'clock_in_at': DateTime.now().toUtc().subtract(const Duration(hours: 5)).toIso8601String(),
        'clock_out_at': state == 'CLOSED' ? DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String() : null,
        'total_distance_km': 312.4,
      };

  Map<String, dynamic> _inspectionRow() => {
        'inspection_id': DesignPreview.inspectionId,
        'template_label': 'Daily tractor check',
        'vehicle_id': DesignPreview.vehicleId,
        'vehicle_plate': 'KAA 123A',
        'status': 'SUBMITTED',
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
        'defect_count': 1,
        'quarantined': false,
        'block_shift': false,
      };

  Map<String, dynamic> _fuelRow() => {
        'fuel_purchase_id': DesignPreview.fuelPurchaseId,
        'vehicle_id': DesignPreview.vehicleId,
        'vehicle_plate': 'KAA 123A',
        'driver_name': 'Amina Wanjiru',
        'station_name': 'Shell Mombasa Road',
        'receipt_date': DateTime.now().toUtc().toIso8601String(),
        'amount_spent': 9030.75,
        'liters_pumped': 50.2,
        'odometer_km': 128450,
        'confidence_score': 0.62,
        'driver_corrected': false,
        'verified': false,
        'badge': 'REVIEW',
        'gauge_before': 'HALF',
        'gauge_after': 'FULL',
        'fuel_card_last_four': '4321',
      };

  Map<String, dynamic> _accidentRow() => {
        'accident_id': DesignPreview.accidentId,
        'reference': 'ACC-7F3A91C2',
        'reported_at': DateTime.now().toUtc().subtract(const Duration(minutes: 20)).toIso8601String(),
        'occurred_at': DateTime.now().toUtc().subtract(const Duration(minutes: 25)).toIso8601String(),
        'location_label': 'Mombasa Rd / Exit 9',
        'severity': 'MODERATE',
        'status': 'OPEN',
        'mayday': false,
        'escalation_tier': 1,
      };

  Map<String, dynamic> _driverRow(String id, String name, String status, bool mfa) => {
        'user_id': id,
        'email': '${name.toLowerCase().replaceAll(' ', '.')}@example.com',
        'full_name': name,
        'mfa_enrolled': mfa,
        'status': status,
        'last_login_at': DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String(),
      };

  Map<String, dynamic> _vehicleStateRow(String plate, String driver, String state) => {
        'vehicle_id': DesignPreview.idForRole(plate.hashCode.abs()),
        'display_state': state,
        'latitude': -1.2921 + (plate.hashCode % 10) * 0.01,
        'longitude': 36.8219 + (plate.hashCode % 7) * 0.01,
        'driver_name': driver,
        'plate': plate,
        'next_eligible_clock_in_at': DateTime.now().toUtc().add(const Duration(hours: 6)).toIso8601String(),
        'odometer_km': 128400 - (plate.hashCode % 50),
        'engine_hours': 4210,
        'vehicle_class': 'TRACTOR',
        'asset_status': 'AVAILABLE',
        'is_online': state != 'OFFLINE',
        'last_position_at': DateTime.now().toUtc().subtract(const Duration(minutes: 1)).toIso8601String(),
      };
}

/// Deterministic preview token (no randomness: fixtures must be stable).
String previewToken() => sha256.convert(utf8.encode('helix-preview')).toString().substring(0, 32);
