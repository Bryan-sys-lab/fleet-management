import 'ids.dart';
import 'session.dart';

/// Deep-link targets. Only the helix:// scheme, only known keys, UUID-validated
/// ids, role-gated. Unknown targets are ignored — never crash, never open a
/// screen the session may not see.
enum DeepLinkKind { accident, dvir, fuel, vehicle, notifications, outbox }

class DeepLink {
  DeepLink(this.kind, this.id);
  final DeepLinkKind kind;
  final String? id;
}

const _known = {'accident', 'dvir', 'fuel', 'vehicle', 'notifications', 'outbox'};

DeepLink? parseDeepLink(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'helix') return null;
  // helix://<kind>/<uuid> — kind in the host, uuid as the single path segment.
  final kind = uri.host.isNotEmpty
      ? uri.host
      : (uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null);
  if (kind == null || !_known.contains(kind)) return null;
  if (uri.host.isNotEmpty && uri.pathSegments.length > 1) return null; // deeper paths are rejected
  final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  if (kind != 'vehicle' && kind != 'notifications' && kind != 'outbox') {
    if (id == null || !isUuid(id)) return null;
  }
  return DeepLink(DeepLinkKind.values.firstWhere((k) => k.name == kind), id);
}

/// Notification taps apply the same validation as deep links.
DeepLink? targetFromNotification(Map<String, dynamic> payload) {
  final entity = payload['entity']?.toString();
  final id = payload['id']?.toString();
  if (entity == null || !_known.contains(entity)) return null;
  if (entity != 'vehicle' && entity != 'notifications' && entity != 'outbox') {
    if (id == null || !isUuid(id)) return null;
  }
  return DeepLink(DeepLinkKind.values.firstWhere((k) => k.name == entity), id);
}

/// `outbox` is a driver-surface deep link; admin roles never receive it.
bool shellAllows(DeepLinkKind kind, bool hasDriverRole) {
  if (kind == DeepLinkKind.outbox) return hasDriverRole;
  return true;
}

/// Deep links open the shell's inbox targeting the entity, or the outbox.
String? routeForDeepLink(DeepLink link, SessionService session) {
  final admin = session.roles.any(adminRoles.contains);
  switch (link.kind) {
    case DeepLinkKind.accident:
      return admin ? '/admin/accidents/${link.id}' : '/driver/inbox';
    case DeepLinkKind.dvir:
      return admin ? '/admin/inspections/${link.id}' : '/driver/inbox';
    case DeepLinkKind.fuel:
      return admin ? '/admin/fuel/${link.id}' : '/driver/inbox';
    case DeepLinkKind.vehicle:
      return admin ? '/admin/map' : '/driver/my-vehicle';
    case DeepLinkKind.notifications:
      return session.roles.contains('DRIVER') ? '/driver/inbox?initial=notifications' : '/admin/inbox';
    case DeepLinkKind.outbox:
      return session.roles.contains('DRIVER') ? '/driver/outbox' : '/driver/inbox';
  }
}
