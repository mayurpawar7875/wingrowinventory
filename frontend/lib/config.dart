// lib/config.dart
class AppConfig {
  // 🌐 Backend URLs
  static const String localAndroid =
      "http://10.0.2.2:4000"; // Android emulator → localhost
  static const String localIOS =
      "http://localhost:4000"; // iOS simulator → localhost
  static const String prod =
      "https://wingrow-inventory.onrender.com"; // Render backend

  // ✅ Choose your default base URL here
  static const String apiBaseUrl = prod;

  // If you want to detect dynamically in main.dart, keep apiBaseUrl = prod
  // and override at runtime depending on platform.
}
