class PlatformAdminConfig {
  /// Off unless the build is made with
  /// `--dart-define=GCC_PLATFORM_ADMIN_ENABLED=true`. While it is off the
  /// platform admin shell has no entry point, no route and no object, and the
  /// app makes no request and stores no value on its behalf.
  static const bool enabled = bool.fromEnvironment('GCC_PLATFORM_ADMIN_ENABLED', defaultValue: false);

  /// The level of the platform admin contract this build speaks, sent on every
  /// call as `X-Platform-Admin-Contract`.
  ///
  /// It is NOT the app version and has nothing to do with the seller app's
  /// force-update gate: that gate is about this binary's release, while the shell
  /// can stop being able to read the platform's answers without the seller app
  /// needing a release, and the seller app can be released without the shell
  /// changing. What matters is not which build is installed but whether it
  /// understands the answers.
  ///
  /// Raise it in the same change that teaches the shell to read a new shape of
  /// answer. A build that sends nothing is level 0 to the server, which is what
  /// every build before this one is: the server may then refuse it, and the app
  /// says so rather than failing in a way nobody can act on.
  static const int contractLevel = 1;
}
