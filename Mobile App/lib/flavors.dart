enum Flavor {
  dev,
  staging,
  production,
}

class F {
  static Flavor? appFlavor;

  static String get name => appFlavor?.name ?? '';

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return '[Dev] NextAi';
      case Flavor.staging:
        return '[Stg] NextAi';
      case Flavor.production:
        return 'NextAi';
      default:
        return 'title';
    }
  }
}
