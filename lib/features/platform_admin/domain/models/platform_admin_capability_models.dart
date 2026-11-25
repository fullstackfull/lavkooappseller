/// A part of the platform admin API that a grant may include, named the way the
/// server names it.
///
/// What the server enforces is what `GET /me` lists, so the app offers a screen
/// only when its capability is listed, and never decides this for itself.
enum PlatformCapability {
  overview,
  markets,
  alerts,
  audit,
  sessions,
  health;

  /// What a grant that names NO capability has.
  ///
  /// Not every capability this version of the app knows: `health` is left out,
  /// to match the server, where a capability added after the first grant was
  /// made is given only to a grant that names it
  /// (`PlatformAdminGrant::NOT_GIVEN_BY_DEFAULT`). The same answer also fits a
  /// server too old to have capabilities at all, which is the other way this
  /// set is reached: such a server has no health endpoint, so offering its
  /// screen would be offering a 404.
  static const Set<PlatformCapability> every = <PlatformCapability>{
    PlatformCapability.overview,
    PlatformCapability.markets,
    PlatformCapability.alerts,
    PlatformCapability.audit,
    PlatformCapability.sessions,
  };

  /// The capability the server named, or null for a name this version of the app has never heard of.
  static PlatformCapability? parse(Object? value) {
    for (final PlatformCapability capability in PlatformCapability.values) {
      if (capability.name == value) return capability;
    }
    return null;
  }

  /// What the `capabilities` member of `GET /me` says. An answer without the member comes from a
  /// server that has no capabilities yet, so every part is open. A member that is not a list is read the way the
  /// server reads a value it cannot read: as none, and never as every one.
  static Set<PlatformCapability> fromJson(Object? value) {
    if (value == null) return every;
    if (value is! List) return const <PlatformCapability>{};

    return value.map(parse).whereType<PlatformCapability>().toSet();
  }
}
