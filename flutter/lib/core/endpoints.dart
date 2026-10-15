/// Endpoint registry — one place where every path lives, with the permission
/// its route enforces. Mirrors the Expo endpoints.ts; screens never write a
/// path literal. Verified against the routers (the source of truth), NOT
/// openapi.yaml.
library;

class Endpoint {
  const Endpoint(this.method, this.path, {this.permission});
  final String method;
  final String path;
  final String? permission;

  String call([Map<String, String> params = const {}]) {
    var out = path;
    params.forEach((k, v) => out = out.replaceAll(':$k', v));
    return out;
  }
}

class E {
  E._();

  // auth / session / devices
  static const login = Endpoint('POST', 'auth/login');
  static const signup = Endpoint('POST', 'auth/signup');
  static const mfaVerify = Endpoint('POST', 'auth/mfa/verify');
  static const refresh = Endpoint('POST', 'auth/refresh');
  static const logout = Endpoint('POST', 'auth/logout');
  static const logoutAll = Endpoint('POST', 'auth/logout-all');
  static const changePassword = Endpoint('POST', 'auth/change-password');
  static const mfaEnroll = Endpoint('POST', 'auth/mfa/enroll', permission: 'manage_own_mfa');
  static const registerDevice = Endpoint('POST', 'auth/devices');
  static const setPin = Endpoint('POST', 'auth/devices/pin');
  static const refreshDeviceToken = Endpoint('POST', 'auth/devices/refresh');
  static const revokeOwnDevice = Endpoint('POST', 'auth/devices/revoke', permission: 'revoke_device');
  static const acceptConsent = Endpoint('POST', 'auth/consent');
  static const passwordResetRequest = Endpoint('POST', 'auth/password-reset/request');
  static const passwordResetComplete = Endpoint('POST', 'auth/password-reset/:resetId/complete');

  // driver self-service
  static const myOnboarding = Endpoint('GET', 'drivers/me/onboarding', permission: 'onboarding:read');
  static const saveOnboardingProfile = Endpoint('POST', 'drivers/me/onboarding/profile', permission: 'onboarding:submit');
  static const submitBackgroundCheck = Endpoint('POST', 'drivers/me/background-check', permission: 'onboarding:submit');
  static const myAssignment = Endpoint('GET', 'drivers/me/assignment', permission: 'assignment:read');
  static const myTrainingStatus = Endpoint('GET', 'drivers/me/training-status', permission: 'training:read');

  // shifts
  static const clockIn = Endpoint('POST', 'shifts/clock-in', permission: 'shift:clock_in');
  static const clockOut = Endpoint('POST', 'shifts/clock-out', permission: 'shift:clock_out');
  static const activeShift = Endpoint('GET', 'shifts/me/active', permission: 'shift:read_own');
  static const myShifts = Endpoint('GET', 'shifts/me', permission: 'shift:read_own');
  static const shiftInbox = Endpoint('GET', 'shifts/verification-inbox', permission: 'shift:read_all');
  static const shiftVerification = Endpoint('GET', 'shifts/:id/verification', permission: 'shift:read_all');
  static const shiftWorkPlan = Endpoint('GET', 'shifts/:id/work-plan', permission: 'shift:read_all');
  static const verifyShift = Endpoint('POST', 'shifts/:id/verify', permission: 'shift:verify');
  static const forceCloseShift = Endpoint('POST', 'shifts/:id/force-close', permission: 'shift:force_close');

  // fuel
  static const fuelCards = Endpoint('GET', 'fuel/cards', permission: 'asset:read');
  static const fuelInbox = Endpoint('GET', 'fuel/reconciliation-inbox', permission: 'fuel:read');
  static const verifyFuel = Endpoint('POST', 'fuel/purchases/:id/verify', permission: 'fuel:verify');
  static const driverFuelPurchase = Endpoint('POST', 'driver/fuel/purchase', permission: 'fuel:submit_purchase');
  static const adminFuelPending = Endpoint('GET', 'admin/fuel/pending', permission: 'fuel:read');
  static const importStatement = Endpoint('POST', 'reconciliation/statements', permission: 'fuel:reconcile');

  // inspections
  static const submitInspection = Endpoint('POST', 'inspections', permission: 'inspection:submit');
  static const inspectionTemplates = Endpoint('GET', 'inspections/templates', permission: 'inspection:read');
  static const myInspections = Endpoint('GET', 'inspections/me', permission: 'inspection:read');
  static const inspections = Endpoint('GET', 'inspections', permission: 'inspection:read');
  static const inspection = Endpoint('GET', 'inspections/:id', permission: 'inspection:read');

  // accidents
  static const mayday = Endpoint('POST', 'accidents/mayday', permission: 'accident:report');
  static const submitAccident = Endpoint('POST', 'accidents', permission: 'accident:report');
  static const accidentMedia = Endpoint('POST', 'accidents/:id/media', permission: 'accident:report');
  static const myAccidents = Endpoint('GET', 'accidents/me', permission: 'accident:read');
  static const accident = Endpoint('GET', 'accidents/:id', permission: 'accident:read');
  static const acknowledgeAccident = Endpoint('POST', 'accidents/:id/acknowledge', permission: 'accident:acknowledge');
  static const verifyTelemetry = Endpoint('GET', 'accidents/:id/telemetry/verify', permission: 'accident:read');

  // trailer
  static const trailerSwap = Endpoint('POST', 'trailer/swap', permission: 'trailer:swap');
  static const trailers = Endpoint('GET', 'trailer', permission: 'trailer:swap');

  // media / telemetry
  static const uploadUrl = Endpoint('POST', 'media/upload-url');
  static const mediaObject = Endpoint('GET', 'media/:id');
  static const phonePoints = Endpoint('POST', 'telemetry/points');

  // dashboard / insights
  static const vehicleStates = Endpoint('GET', 'dashboard/vehicle-states', permission: 'report:read');
  static const anomalies = Endpoint('GET', 'anomalies', permission: 'report:read');
  static const anomaly = Endpoint('GET', 'anomalies/:id', permission: 'anomaly:read');
  static const analytics = Endpoint('GET', 'reports/analytics', permission: 'fuel:read');
  static const expiringDocs = Endpoint('GET', 'documents/expiring', permission: 'document:read');
  static const docDetail = Endpoint('GET', 'documents/:id', permission: 'document:read');
  static const setRenewalNote = Endpoint('POST', 'documents/:id/renewal-note', permission: 'document:manage');

  // notifications
  static const notifications = Endpoint('GET', 'notifications', permission: 'notification:read');
  static const notificationCount = Endpoint('GET', 'notifications/count', permission: 'notification:read');
  static const markRead = Endpoint('POST', 'notifications/:id/read', permission: 'notification:read');
  static const markAllRead = Endpoint('POST', 'notifications/read-all', permission: 'notification:read');

  // admin: people
  static const drivers = Endpoint('GET', 'drivers', permission: 'user:read');
  static const driverDetail = Endpoint('GET', 'drivers/:id', permission: 'user:read');
  static const createDriver = Endpoint('POST', 'drivers', permission: 'user:manage');
  static const approveDriver = Endpoint('POST', 'drivers/:id/approve', permission: 'user:manage');
  static const suspendUser = Endpoint('POST', 'admin/users/:id/suspend', permission: 'user:manage');
  static const reinstateUser = Endpoint('POST', 'admin/users/:id/reinstate', permission: 'user:manage');
  static const revokeSessions = Endpoint('POST', 'sessions/revoke', permission: 'user:manage');
  static const revokeDevice = Endpoint('POST', 'devices/:deviceId/revoke', permission: 'device:revoke');

  // vehicles
  static const vehicles = Endpoint('GET', 'vehicles', permission: 'asset:read');
  static const vehicle = Endpoint('GET', 'vehicles/:id', permission: 'asset:read');
  static const createVehicle = Endpoint('POST', 'vehicles', permission: 'asset:create');
  static const updateVehicle = Endpoint('PATCH', 'vehicles/:id', permission: 'asset:update');
  static const reportVehicleIssue = Endpoint('POST', 'vehicles/:vehicleId/issues', permission: 'vehicle:report');
  static const vehicleIssues = Endpoint('GET', 'vehicles/:vehicleId/issues', permission: 'asset:read');

  // training / maintenance / privacy / hardware
  static const trainingLessons = Endpoint('GET', 'training/lessons', permission: 'training:read');
  static const trainingRoster = Endpoint('GET', 'training/roster', permission: 'training:review');
  static const completeTraining = Endpoint('POST', 'training/lessons/:id/complete', permission: 'training:complete');
  static const maintenanceList = Endpoint('GET', 'maintenance', permission: 'maintenance:read');
  static const createMaintenance = Endpoint('POST', 'maintenance/work-orders', permission: 'maintenance:record');
  static const exportRequests = Endpoint('GET', 'privacy/export-request', permission: 'privacy:request_own');
  static const createExportRequest = Endpoint('POST', 'privacy/export-request', permission: 'privacy:request_own');
  static const tenantPrivacyRequests = Endpoint('GET', 'privacy/requests', permission: 'privacy:view_requests_tenant');
  static const hardwarePair = Endpoint('POST', 'admin/hardware/pair', permission: 'asset:update');
  static const hardwarePending = Endpoint('GET', 'admin/hardware/pending', permission: 'asset:read');

  // consent
  static const consentStatus = Endpoint('GET', 'me/consent');
}
