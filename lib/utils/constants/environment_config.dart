enum Environment { dev, prod }

class EnvironmentConfig {
  //static Environment currentEnvironment = Environment.prod;
  static Environment currentEnvironment = Environment.dev;

  static void setEnvironment(Environment env) {
    currentEnvironment = env;
  }

  static bool get isDev => currentEnvironment == Environment.dev;
  static bool get isProd => currentEnvironment == Environment.prod;

  static String get appName => isDev ? 'KK Dev' : 'Krishi Karobar';
  static String get firebaseProjectId =>
      isDev ? 'krishi-karobar-dev' : 'krishi-karobar-8a470';
}
