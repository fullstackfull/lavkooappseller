class PlatformAdminConfig {
  /// Off unless the build is made with
  /// `--dart-define=GCC_PLATFORM_ADMIN_ENABLED=true`. While it is off the
  /// platform admin shell has no entry point, no route and no object, and the
  /// app makes no request and stores no value on its behalf.
  static const bool enabled = bool.fromEnvironment('GCC_PLATFORM_ADMIN_ENABLED', defaultValue: false);
}
