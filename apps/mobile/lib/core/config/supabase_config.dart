/// Configuration parameters for Supabase integration in EcoCampus.
///
/// Uses compile-time environment variables (`--dart-define`) to avoid hardcoding
/// credentials in source while providing default fallbacks for the target Supabase project.
class SupabaseConfig {
  const SupabaseConfig._();

  /// The Supabase Project URL.
  /// Can be overridden via `--dart-define=SUPABASE_URL=<url>`.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://scwssqiocxotgmjgwqjg.supabase.co',
  );

  /// The Supabase Publishable Client Key.
  /// Can be overridden via `--dart-define=SUPABASE_PUBLISHABLE_KEY=<key>`
  /// or `--dart-define=SUPABASE_ANON_KEY=<key>`.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_KawBvIvaEdfkRSnMZy6HOQ_P0tClS3n',
    ),
  );

  /// Backwards-compatible alias for [publishableKey].
  static const String anonKey = publishableKey;

  /// Checks if Supabase has non-empty configuration credentials.
  static bool get isConfigured =>
      url.isNotEmpty &&
      publishableKey.isNotEmpty &&
      !url.contains('YOUR_SUPABASE_URL');
}
