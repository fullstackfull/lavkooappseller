class SellerPermissionConfig {
  /// Off unless the build is made with `--dart-define=GCC_ROLE_SCREENS_ENABLED=true`. While it is off the app asks the server
  /// nothing about the role it signed in as and hides nothing, so an existing build draws exactly the screens it always drew.
  static const bool enabled = bool.fromEnvironment('GCC_ROLE_SCREENS_ENABLED', defaultValue: false);
}
