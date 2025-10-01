// lib/main.dart
import 'package:flutter/material.dart';
import 'api_service.dart';
import 'config.dart'; // ✅ now we import AppConfig

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

  @override
  Widget build(BuildContext context) {
    // ✅ Always use Render backend URL from config.dart
    final api = ApiService(AppConfig.apiBaseUrl);

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
