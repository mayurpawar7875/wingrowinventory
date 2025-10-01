// lib/config.dart
class AppConfig {
  // 🌐 Backend URLs
  static const String localAndroid =
      "http://10.0.2.2:4000"; // Android emulator → localhost backend
  static const String localIOS =
      "http://localhost:4000"; // iOS simulator → localhost backend
  static const String prod =
      "https://wingrowinventory.onrender.com"; // ✅ Render backend (production)

  // ✅ Default API base URL
  // Change this line if you want to switch between local and prod
  static const String apiBaseUrl = prod;

  // 🚀 Optional: Support for build-time override using --dart-define
  static const String apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: apiBaseUrl,
  );
}
