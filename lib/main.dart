import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'routes.dart';
import 'screens/splash_screen.dart';
import 'services/secure_auth_service.dart';
import 'services/secure_storage_service.dart';
import 'services/local_storage_service.dart';
import 'api/secure_tmdb_api.dart';
import 'utils/constants.dart';
import 'utils/security_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Force portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Clear old logs
  await SecurityLogger.cleanupLogs(keepDays: 7);
  
  // Initialize the secure storage service
  final secureStorageService = SecureStorageService();
  
  // Initialize the local storage service for backward compatibility
  final localStorageService = LocalStorageService();
  await localStorageService.initialize();
  
  // Check the preferred theme
  final isDarkMode = await localStorageService.getDarkModePreference();
  
  runApp(MyApp(
    secureStorageService: secureStorageService,
    localStorageService: localStorageService,
    initialThemeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
  ));
}

class MyApp extends StatefulWidget {
  final SecureStorageService secureStorageService;
  final LocalStorageService localStorageService;
  final ThemeMode initialThemeMode;
  
  const MyApp({
    super.key,
    required this.secureStorageService,
    required this.localStorageService,
    this.initialThemeMode = ThemeMode.system,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;
  late SecureAuthService _authService;
  late SecureTMDBApi _apiService;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialThemeMode;
    _authService = SecureAuthService(widget.secureStorageService);
    _apiService = SecureTMDBApi();
    
    // Listen for theme changes
    widget.localStorageService.getUserPreferences().then((prefs) {
      setState(() {
        _themeMode = prefs.darkMode ? ThemeMode.dark : ThemeMode.light;
      });
    });
    
    SecurityLogger.info('Application started');
  }

  void _updateThemeMode(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authService),
        Provider.value(value: widget.secureStorageService),
        Provider.value(value: widget.localStorageService),
        Provider.value(value: _apiService),
        StreamProvider<bool>(
          create: (_) => Stream.periodic(
            const Duration(seconds: 1),
            (_) => _themeMode == ThemeMode.dark,
          ),
          initialData: _themeMode == ThemeMode.dark,
          updateShouldNotify: (_, __) => true,
        ),
      ],
      child: Consumer<bool>(
        builder: (context, isDark, _) {
          widget.localStorageService.setDarkModePreference(isDark);
          return MaterialApp(
            title: AppConstants.appName,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            onGenerateRoute: AppRoutes.generateRoute,
            initialRoute: '/splash',
            routes: {
              '/splash': (context) => const SplashScreen(),
            },
          );
        },
      ),
    );
  }
}