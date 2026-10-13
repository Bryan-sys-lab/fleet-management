import type { Principal, RoleCode } from '@fleet/shared';
import type { Role } from '../state/roles';

/**
 * Design-review bypass: sign in without the API so every screen and every control can be
 * inspected without a backend, a tenant or credentials.
 *
 * It is ON in a debug build (`__DEV__`, which Metro inlines to `false` in release/production) or when
 * `EXPO_PUBLIC_DEV_AUTH_BYPASS=1` is set. A release build can therefore never enter this state, and
 * the bypass principal carries no token — the API will simply 401 anything it calls, which is the
 * point: this is for layout, i18n and navigation, not data.
 */
export const DEV_AUTH_BYPASS: boolean =
  (typeof process !== 'undefined' && process.env?.EXPO_PUBLIC_DEV_AUTH_BYPASS === '1') ||
  (typeof __DEV__ !== 'undefined' && __DEV__ === true);

/** Fixed ids so the bypass looks stable across reloads (queue owner, cache keys). */
const USER_ID = '00000000-0000-4000-8000-000000000001';
const TENANT_ID = '00000000-0000-4000-8000-000000000002';

/**
 * `permissions: null` is deliberate: `can()` then returns `true` for every code, so nothing
 * permission-gated is hidden while reviewing the design.
 */
export function bypassPrincipal(role: Role): Principal {
  const roles: RoleCode[] = role === 'ADMIN'
    ? ['ADMIN', 'FLEET_MANAGER', 'DISPATCHER', 'FINANCE', 'AUDITOR']
    : ['DRIVER'];
  return {
    user_id: USER_ID,
    tenant_id: TENANT_ID,
    email: role === 'ADMIN' ? 'admin@helix.dev' : 'driver@helix.dev',
    phone: '+254700000000',
    roles,
    locale: 'en',
    session_id: null,
    permissions: null,
  };
}

/** Both experiences at once, so the role switcher can offer them. */
export const BYPASS_ROLES: Role[] = ['DRIVER', 'ADMIN'];
