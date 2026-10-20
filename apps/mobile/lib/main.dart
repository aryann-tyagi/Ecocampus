import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/custom_bottom_nav.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/home/data/companion_provider.dart';
import 'features/home/presentation/student_home_screen.dart';
import 'features/map/presentation/campus_map_screen.dart';
import 'features/reports_tracking/presentation/my_reports_screen.dart';
import 'features/rewards/presentation/rewards_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final prefs = await SharedPreferences.getInstance();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  // Initialize push notification & local notification handlers safely
  await PushNotificationService.instance.initialize();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const EcoCampusApp(),
    ),
  );
}

class EcoCampusApp extends StatelessWidget {
  final Widget? home;

  const EcoCampusApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: PushNotificationService.navigatorKey,
      title: 'Eco Campus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: home ?? const AuthGate(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          StudentHomeScreen(
            isActive: _currentIndex == 0,
            onNavigateToReports: () {
              if (mounted) setState(() => _currentIndex = 2);
            },
            onNavigateToRewards: () {
              if (mounted) setState(() => _currentIndex = 3);
            },
          ),
          CampusMapScreen(isActive: _currentIndex == 1),
          const MyReportsScreen(),
          RewardsScreen(isActive: _currentIndex == 3),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_currentIndex != index) {
            setState(() => _currentIndex = index);
          }
        },
      ),
    );
  }
}
