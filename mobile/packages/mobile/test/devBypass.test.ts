import { describe, expect, it } from 'vitest';
import { BYPASS_ROLES, bypassPrincipal } from '../src/core/devBypass';
import { can } from '@fleet/shared';

/**
 * The design-review bypass exists so every screen can be opened without a backend. These tests pin
 * the two properties the rest of the app depends on: both experiences are offered, and the bypass
 * principal hides no permission-gated control.
 */
describe('devBypass', () => {
  it('offers both experiences so every stack is reachable', () => {
    expect(BYPASS_ROLES).toEqual(['DRIVER', 'ADMIN']);
  });

  it.each(['DRIVER', 'ADMIN'] as const)('builds a principal for %s with an id and roles', (role) => {
    const p = bypassPrincipal(role);
    expect(p.user_id).toMatch(/^[0-9a-f-]{36}$/);
    expect(p.roles.length).toBeGreaterThan(0);
    expect(role === 'ADMIN' ? p.roles : ['DRIVER']).toContain(role);
  });

  it('the bypass principal passes every permission check, so nothing is hidden while reviewing', () => {
    // `permissions: null` is the documented "union absent" case; the control shows and the server's 403 decides.
    expect(bypassPrincipal('DRIVER').permissions).toBeNull();
    expect(can(bypassPrincipal('ADMIN'), 'asset:create')).toBe(true);
    expect(can(bypassPrincipal('DRIVER'), 'privacy:view_requests_tenant')).toBe(true);
    expect(can(bypassPrincipal('DRIVER'), 'any:unknown:code' as never)).toBe(true);
  });

  it('carries no token, so the bypass can never authenticate against the API', () => {
    expect(bypassPrincipal('DRIVER').session_id).toBeNull();
  });
});
