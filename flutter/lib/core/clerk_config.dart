
/// Clerk configuration. Clerk is the system's managed auth provider:
/// sign-in, sign-up, MFA, password reset, and session management all live in Clerk.
///
/// Values come from the environment / platform secret store. In dev, use the
/// Clerk instance configured for local development (clerk.lcl.accounts.dev).
class ClerkConfig {
  const ClerkConfig({
    required this.publishableKey,
    required this.frontendUrl,
    required this.signInUrl,
    required this.signUpUrl,
    required this.userProfileUrl,
  });

  /// Clerk publishable key (client-side only, safe to embed).
  final String publishableKey;

  /// Clerk frontend URL, e.g. https://helix.lcl.accounts.dev
  final String frontendUrl;

  /// Full sign-in URL.
  final String signInUrl;

  /// Full sign-up URL.
  final String signUpUrl;

  /// Full user profile URL (for managing MFA, password, etc.)
  final String userProfileUrl;

  static ClerkConfig fromEnv() {
    // These are injected at build time via flutter config / env dart file.
    // For development, point at a local Clerk instance.
    return const ClerkConfig(
      publishableKey: 'pk_test_placeholder',
      frontendUrl: 'https://helix.lcl.accounts.dev',
      signInUrl: 'https://helix.lcl.accounts.dev/sign-in',
      signUpUrl: 'https://helix.lcl.accounts.dev/sign-up',
      userProfileUrl: 'https://helix.lcl.accounts.dev/user-profile',
    );
  }

  /// Clerk Frontend API base URL for REST calls (sign-in, sign-up, MFA, etc.)
  String get clientApiBase => '$frontendUrl/v1/client';
}
