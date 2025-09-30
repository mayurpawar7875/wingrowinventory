// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

import 'api_service.dart';
// import 'config.dart'; // <-- Add this file with AppConfig if you want
import 'screens/login_screen.dart';
import 'screens/reimbursement_screen.dart';
import 'screens/manager_approvals_screen.dart';
import 'screens/my_claims_screen.dart';
import 'screens/request_item_screen.dart';
import 'screens/my_item_requests_screen.dart';
import 'screens/manager_item_requests_screen.dart';
import 'screens/stock_screen.dart';
import 'ui/app_theme.dart';

void main() {
  runApp(const WingrowApp());
}

class WingrowApp extends StatelessWidget {
  const WingrowApp({super.key});

  // Decide the base URL depending on where you run the app.
  // - For Android emulator: use 10.0.2.2:<port> to reach your laptop backend
  // - For iOS simulator: use http://localhost:<port>
  // - For real devices: use your machine IP (e.g., http://192.168.1.7:<port>) or your Render URL
  // - For production/testing on cloud: use your HTTPS Render URL
  String _computeBaseUrl() {
    // 1) Prefer a production URL if you’ve set one in config.dart
    //    e.g., AppConfig.apiBaseUrl = "https://wingrow-inventory.onrender.com"
    const String? prod =
        String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (prod.isNotEmpty) return prod;

    // 2) If you use config.dart with constants, uncomment:
    // return AppConfig.apiBaseUrl;

    // 3) Dev defaults for local runs (only if you haven’t set config/app env):
    const int port = 4000;

    if (kIsWeb) {
      // For Flutter Web dev server hitting local backend
      return 'http://localhost:$port';
    }

    if (Platform.isAndroid) {
      // Android emulator cannot reach "localhost" on your laptop
      return 'http://10.0.2.2:$port';
    }

    // iOS simulator can use localhost
    if (Platform.isIOS || Platform.isMacOS) {
      return 'http://localhost:$port';
    }

    // Fallback
    return 'http://localhost:$port';
  }

  @override
  Widget build(BuildContext context) {
    // QUICK SWITCHES:
    // - To use your Render backend for testing on real phones, just set:
    //   final api = ApiService('https://wingrow-inventory.onrender.com');
    // - To keep smart auto-detection (emulators vs local), use _computeBaseUrl()
    final api = ApiService(_computeBaseUrl());

    return MaterialApp(
      title: 'Wingrow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: '/login',
      routes: {
        // Auth
        '/login': (_) => LoginScreen(api: api),

        // Organizer
        '/home': (_) => ReimbursementScreen(api: api),
        '/reimburse': (_) => ReimbursementScreen(api: api),
        '/my-claims': (_) => MyClaimsScreen(api: api),
        '/request-item': (_) => RequestItemScreen(api: api),
        '/my-item-requests': (_) => MyItemRequestsScreen(api: api),

        // Manager
        '/approvals': (_) => ManagerApprovalsScreen(api: api),
        '/stock': (_) => StockScreen(api: api),
        '/mgr-item-requests': (_) => ManagerItemRequestsScreen(api: api),

        // Alias so older navigation calls still work
        '/mgr-requests': (_) => ManagerItemRequestsScreen(api: api),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Not found')),
          body: Center(child: Text('No route named "${settings.name}"')),
        ),
      ),
    );
  }
}
