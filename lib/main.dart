import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'providers/theme_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_shell.dart';
import 'screens/best_time/best_time_screen.dart';
import 'screens/smart_route/smart_route_screen.dart';
import 'screens/admin/admin_panel.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CrowdSenseApp());
}

class CrowdSenseApp extends StatelessWidget {
  const CrowdSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'CrowdSense AI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/auth': (context) => const AuthScreen(),
              '/home': (context) => const MainShell(),
              '/best-time': (context) => const BestTimeScreen(),
              '/smart-route': (context) => const SmartRouteScreen(),
              '/admin': (context) => const AdminPanel(),
            },
          );
        },
      ),
    );
  }
}
